#!/usr/bin/env python3
"""Motor de instalación automática de Quantum Linux (sin preguntas).

Lee el archivo de respuestas (ver RESPUESTAS.md), particiona, copia el sistema y lo deja
listo, igual que el instalador gráfico (Calamares). Avisa el avance por la salida estándar,
una línea JSON por evento:  {"step": "...", "state": "running|ok|error", "percent": 0-100, "detail": "..."}
Se ejecuta como root en el sistema en vivo.

Uso: engine.py RESPUESTAS.json [--dry-run]
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

TARGET = Path("/mnt/quantum")
SFS = "/run/archiso/bootmnt/quantum/x86_64/airootfs.sfs"
EFI_GUID = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
GiB = 1024 ** 3

STEPS = [
    ("disk", "Preparando el disco", 4),
    ("copy", "Copiando Quantum Linux", 55),
    ("system", "Configurando el sistema", 10),
    ("user", "Creando tu cuenta", 3),
    ("boot", "Preparando el arranque", 18),
    ("extras", "Dejando listas tus apps y tus cosas", 10),
]
done_weight = 0
current = ""


def emit(**kw):
    print(json.dumps(kw, ensure_ascii=False), flush=True)


def progress(frac, detail=""):
    w = dict((k, w) for k, _, w in STEPS)[current]
    total = sum(w for _, _, w in STEPS)
    emit(step=current, state="running", percent=round(100 * (done_weight + w * min(1, frac)) / total, 1), detail=detail)


def run(cmd, check=True, chroot=False, inp=None, **kw):
    if chroot:
        cmd = ["arch-chroot", str(TARGET)] + cmd
    r = subprocess.run(cmd, capture_output=True, text=True, input=inp, **kw)
    if check and r.returncode != 0:
        raise RuntimeError(f"{' '.join(map(str, cmd[:6]))}: {(r.stderr or r.stdout).strip()[-400:]}")
    return r.stdout


def lsblk(dev=None):
    out = run(["lsblk", "-J", "-b", "-o", "NAME,PATH,TYPE,SIZE,SERIAL,MODEL,TRAN,RM,ROTA,PARTTYPE,PARTUUID,FSTYPE,LABEL,MOUNTPOINTS"]
              + ([dev] if dev else []))
    return json.loads(out)["blockdevices"]


# ------------------------------------------------------------------ disco

def boot_disk():
    """Disco del pendrive del que arrancó el sistema en vivo (no se toca nunca)."""
    src = run(["findmnt", "-no", "SOURCE", "/run/archiso/bootmnt"], check=False).strip()
    if not src:
        return ""
    return "/dev/" + run(["lsblk", "-no", "PKNAME", src], check=False).strip()


def find_disk(spec):
    """El disco elegido en Windows: por número de serie, o por tamaño si no hay serie."""
    usb = boot_disk()
    disks = [d for d in lsblk() if d["type"] == "disk" and d["path"] != usb and not d["path"].startswith("/dev/zram")
             and not d["path"].startswith("/dev/loop") and not d["path"].startswith("/dev/sr")]
    serial = (spec.get("serial") or "").strip().lower()
    if serial:
        for d in disks:
            if (d.get("serial") or "").strip().lower() == serial:
                return d
    # Windows y Linux pueden informar tamaños apenas distintos: se acepta 0,5 % de diferencia
    size = spec.get("size") or 0
    cands = [d for d in disks if size and abs(int(d["size"]) - size) <= size * 0.005]
    if len(cands) == 1:
        return cands[0]
    if not size and len(disks) == 1:
        return disks[0]
    raise RuntimeError("No pude identificar con seguridad el disco elegido en Windows")


def free_regions(dev):
    """Huecos libres del disco: [(inicio, fin, tamaño)] en sectores."""
    out = run(["parted", "-m", "-s", dev, "unit", "s", "print", "free"])
    regions = []
    for line in out.splitlines():
        p = line.rstrip(";").split(":")
        if len(p) >= 5 and p[4] == "free":
            a, b = int(p[1].rstrip("s")), int(p[2].rstrip("s"))
            regions.append((a, b, b - a + 1))
    return regions


def sector_size(dev):
    return int(Path(f"/sys/block/{Path(dev).name}/queue/logical_block_size").read_text())


def part_path(dev, n):
    return f"{dev}p{n}" if dev[-1].isdigit() else f"{dev}{n}"


def settle():
    run(["udevadm", "settle"], check=False)
    time.sleep(1)


def partition(ans, dry):
    """Devuelve (esp, boot, root) y si la ESP es nueva."""
    disk = find_disk(ans.get("disk", {}))
    dev = disk["path"]
    progress(0.1, f"Disco: {disk.get('model') or dev} ({int(disk['size']) // 10**9} GB)")
    if ans["mode"] == "wipe":
        if dry:
            return dev, None
        run(["wipefs", "-a", dev], check=False)
        run(["sgdisk", "-Z", dev])
        run(["sgdisk", "-n", "1:0:+512M", "-t", "1:ef00", "-c", "1:EFI",
             "-n", "2:0:+1G", "-t", "2:8300", "-c", "2:quantum-boot",
             "-n", "3:0:0", "-t", "3:8300", "-c", "3:quantum", dev])
        settle()
        return dev, (part_path(dev, 1), part_path(dev, 2), part_path(dev, 3), True)
    # «free»: el hueco que dejó Windows al achicar su partición
    pt = lsblk(dev)[0]
    esp = next((c["path"] for c in pt.get("children", []) if (c.get("parttype") or "").lower() == EFI_GUID), None)
    if not esp:
        raise RuntimeError("El disco no tiene partición EFI: no se puede instalar junto a Windows en este PC")
    regs = free_regions(dev)
    if not regs:
        raise RuntimeError("No encontré espacio libre en el disco")
    a, b, n = max(regs, key=lambda r: r[2])
    ss = sector_size(dev)
    if n * ss < ans.get("minFree", 20 * GiB):
        raise RuntimeError(f"El espacio libre ({n * ss // 10**9} GB) es menor que el que se reservó en Windows")
    if dry:
        return dev, None
    # alinear a 1 MiB
    al = (1024 * 1024) // ss
    start = ((a + al - 1) // al) * al
    boot_end = start + (GiB // ss) - 1
    before = {c["path"] for c in pt.get("children", [])}
    run(["sgdisk", "-n", f"0:{start}:{boot_end}", "-t", "0:8300", "-c", "0:quantum-boot", dev])
    run(["sgdisk", "-n", f"0:{boot_end + 1}:{b}", "-t", "0:8300", "-c", "0:quantum", dev])
    run(["partprobe", dev], check=False)
    settle()
    new = [c for c in lsblk(dev)[0].get("children", []) if c["path"] not in before]
    new.sort(key=lambda c: int(c["size"]))
    if len(new) != 2:
        raise RuntimeError("No se crearon bien las particiones nuevas")
    return dev, (esp, new[0]["path"], new[1]["path"], False)


def format_and_mount(dev, parts):
    esp, boot, root, new_esp = parts
    if new_esp:
        run(["mkfs.vfat", "-F", "32", "-n", "EFI", esp])
    run(["mkfs.ext4", "-F", "-q", "-L", "quantum-boot", boot])
    run(["mkfs.btrfs", "-f", "-q", "-L", "quantum", root])
    progress(0.6, "Creando los volúmenes")
    TARGET.mkdir(parents=True, exist_ok=True)
    run(["mount", root, str(TARGET)])
    for sv in ("@", "@home", "@cache", "@log"):
        run(["btrfs", "subvolume", "create", str(TARGET / sv)])
    run(["umount", str(TARGET)])
    ssd = Path(f"/sys/block/{Path(dev).name}/queue/rotational").read_text().strip() == "0"
    opts = "noatime,compress=zstd:1" + (",discard=async" if ssd else "")
    run(["mount", "-o", f"subvol=@,{opts}", root, str(TARGET)])
    for sv, mp in (("@home", "home"), ("@cache", "var/cache"), ("@log", "var/log")):
        (TARGET / mp).mkdir(parents=True, exist_ok=True)
        run(["mount", "-o", f"subvol={sv},{opts}", root, str(TARGET / mp)])
    (TARGET / "boot").mkdir(exist_ok=True)
    run(["mount", boot, str(TARGET / "boot")])
    (TARGET / "boot/efi").mkdir(exist_ok=True)
    run(["mount", "-o", "umask=0077", esp, str(TARGET / "boot/efi")])


# ------------------------------------------------------------------ copia

def unpack():
    p = subprocess.Popen(["unsquashfs", "-f", "-percentage", "-d", str(TARGET), SFS],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    last = -1
    for line in p.stdout:
        line = line.strip()
        if line.isdigit() and int(line) != last:
            last = int(line)
            progress(last / 100, f"{last} %")
    if p.wait() != 0:
        raise RuntimeError("No se pudo copiar el sistema")


# ------------------------------------------------------------------ sistema

KEYMAPS = {"latam": "la-latin1", "es": "es", "us": "us", "gb": "uk", "br": "br-abnt2", "pt": "pt-latin1",
           "fr": "fr", "de": "de", "it": "it"}


def configure(ans):
    t = TARGET
    run(["/usr/lib/quantum/installer/cleanup-live"], chroot=True, check=False)
    progress(0.2, "Idioma y hora")
    run(["systemd-machine-id-setup", "--root", str(t)], check=False)
    loc = ans.get("locale", "es_CL.UTF-8")
    gen = (t / "etc/locale.gen").read_text()
    for l in {loc, "en_US.UTF-8"}:
        gen = re.sub(rf"^#\s*({re.escape(l)} .*)$", r"\1", gen, flags=re.M)
    (t / "etc/locale.gen").write_text(gen)
    run(["locale-gen"], chroot=True)
    (t / "etc/locale.conf").write_text(f"LANG={loc}\n")
    tz = ans.get("timezone", "UTC")
    if (t / "usr/share/zoneinfo" / tz).exists():
        lt = t / "etc/localtime"
        lt.unlink(missing_ok=True)
        lt.symlink_to(f"/usr/share/zoneinfo/{tz}")
    run(["hwclock", "--systohc"], chroot=True, check=False)
    kb = ans.get("keyboard", {})
    lay, var = kb.get("layout") or "latam", kb.get("variant") or ""
    (t / "etc/vconsole.conf").write_text(f"KEYMAP={KEYMAPS.get(lay, 'us')}\n")
    x = t / "etc/X11/xorg.conf.d"
    x.mkdir(parents=True, exist_ok=True)
    (x / "00-keyboard.conf").write_text(
        'Section "InputClass"\n    Identifier "system-keyboard"\n    MatchIsKeyboard "on"\n'
        f'    Option "XkbLayout" "{lay}"\n' + (f'    Option "XkbVariant" "{var}"\n' if var else "") + "EndSection\n")
    progress(0.45, "Particiones")
    fstab = run(["genfstab", "-U", str(t)])
    fstab = re.sub(r",subvolid=\d+", "", fstab)
    with open(t / "etc/fstab", "a") as f:
        f.write(fstab + "\ntmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0\n")
    progress(0.6, "Servicios")
    for s in ("NetworkManager", "bluetooth", "sddm", "fstrim.timer", "power-profiles-daemon", "cups",
              "avahi-daemon", "systemd-timesyncd", "paccache.timer"):
        run(["systemctl", "enable", s], chroot=True, check=False)
    run(["systemctl", "mask", "systemd-networkd-wait-online"], chroot=True, check=False)
    run(["systemctl", "disable", "NetworkManager-wait-online"], chroot=True, check=False)
    # las redes Wi-Fi que se usaron en el sistema en vivo
    nm = Path("/etc/NetworkManager/system-connections")
    if nm.is_dir():
        shutil.copytree(nm, t / "etc/NetworkManager/system-connections", dirs_exist_ok=True)
    progress(0.75, "Drivers")
    run(["/usr/lib/quantum/installer/hw-cleanup"], chroot=True, check=False)


def create_user(ans):
    u = ans["user"]
    login = u["login"]
    if not re.fullmatch(r"[a-z_][a-z0-9_-]{0,31}", login) or login in ("root", "liveuser"):
        raise RuntimeError("Nombre de usuario no válido")
    for g in ("gamemode", "autologin"):
        run(["groupadd", "-f", "-r", g], chroot=True, check=False)
    groups = "users,wheel,lp,video,network,storage,audio,gamemode" + (",autologin" if u.get("autologin") else "")
    run(["useradd", "-m", "-G", groups, "-s", "/bin/bash", "-c", u.get("name", login), login], chroot=True)
    run(["usermod", "-p", u["password"], login], chroot=True)
    run(["chmod", "700", f"/home/{login}"], chroot=True)
    sd = TARGET / "etc/sudoers.d"
    sd.mkdir(exist_ok=True)
    (sd / "10-installer").write_text("%wheel ALL=(ALL:ALL) ALL\n")
    os.chmod(sd / "10-installer", 0o440)
    host = ans.get("hostname") or f"{login}-quantum"
    (TARGET / "etc/hostname").write_text(host + "\n")
    (TARGET / "etc/hosts").write_text(f"127.0.0.1 localhost\n::1 localhost\n127.0.1.1 {host}\n")
    if u.get("autologin"):
        c = TARGET / "etc/sddm.conf.d"
        c.mkdir(parents=True, exist_ok=True)
        (c / "autologin.conf").write_text(f"[Autologin]\nUser={login}\nSession=quantum\n")
    return login


def bootloader(ans, new_esp, answers_dir):
    t = TARGET
    run(["plymouth-set-default-theme", "quantum"], chroot=True, check=False)
    conf = t / "etc/mkinitcpio.conf"
    txt = conf.read_text()
    hooks = "base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck grub-btrfs-overlayfs"
    txt = re.sub(r"^HOOKS=\(.*\)$", f"HOOKS=({hooks})", txt, flags=re.M)
    conf.write_text(txt)
    progress(0.1, "Imagen de arranque")
    run(["mkinitcpio", "-P"], chroot=True)
    progress(0.55, "Menú de arranque")
    g = t / "etc/default/grub"
    txt = g.read_text()
    vals = {"GRUB_TIMEOUT": "3", "GRUB_DEFAULT": "0", "GRUB_DISABLE_SUBMENU": "true", "GRUB_TERMINAL_OUTPUT": "gfxterm",
            "GRUB_DISABLE_RECOVERY": "true", "GRUB_DISABLE_OS_PROBER": "false",
            "GRUB_CMDLINE_LINUX_DEFAULT": '"quiet splash loglevel=3 nowatchdog"'}
    for k, v in vals.items():
        if re.search(rf"^#?\s*{k}=", txt, re.M):
            txt = re.sub(rf"^#?\s*{k}=.*$", f"{k}={v}", txt, flags=re.M)
        else:
            txt += f"\n{k}={v}\n"
    g.write_text(txt)
    run(["/usr/lib/quantum/installer/grub-theme"], chroot=True, check=False)
    # arranque firmado (también funciona sin Secure Boot): shim + GRUB + entrada «Quantum Linux» primera
    sb = ans.get("secureboot", {})
    a = t / "var/lib/quantum/answers"
    a.mkdir(parents=True, exist_ok=True)
    if sb.get("enabled"):
        (a / "secureboot").touch()
    # llave de este PC creada en Windows (ya quedó pedida allí: no hace falta otra pantalla azul)
    pfx = answers_dir / "MOK.pfx"
    if pfx.is_file():
        for extra in ([], ["-legacy"]):        # Windows a veces usa cifrados antiguos en el .pfx
            key = subprocess.run(["openssl", "pkcs12", "-in", str(pfx), "-nocerts", "-nodes", "-passin", "pass:quantum"] + extra,
                                 capture_output=True, text=True)
            crt = subprocess.run(["openssl", "pkcs12", "-in", str(pfx), "-clcerts", "-nokeys", "-passin", "pass:quantum"] + extra,
                                 capture_output=True, text=True)
            if key.returncode == 0 and crt.returncode == 0 and "PRIVATE KEY" in key.stdout:
                k = subprocess.run(["openssl", "pkey"], input=key.stdout, capture_output=True, text=True).stdout
                c = subprocess.run(["openssl", "x509"], input=crt.stdout, capture_output=True, text=True).stdout
                (a / "MOK.key").write_text(k); (a / "MOK.crt").write_text(c)
                os.chmod(a / "MOK.key", 0o600)
                break
    for f in ("MOK.key", "MOK.crt"):
        if (answers_dir / f).is_file():
            shutil.copy2(answers_dir / f, a / f)
            os.chmod(a / f, 0o600)
    (a / "mok-password").write_text(sb.get("mokPassword", "quantum"))
    progress(0.7, "Arranque seguro")
    run(["/usr/lib/quantum/secureboot/setup"], chroot=True)
    progress(0.85, "Buscando Windows")
    run(["grub-mkconfig", "-o", "/boot/grub/grub.cfg"], chroot=True)
    for f in ("MOK.key", "MOK.crt", "mok-password"):
        (a / f).unlink(missing_ok=True)


def extras(ans, login, data_dir):
    t = TARGET
    run(["/usr/lib/quantum/installer/setup-snapper"], chroot=True, check=False)
    progress(0.3, "Tus apps")
    q = t / "var/lib/quantum"
    q.mkdir(parents=True, exist_ok=True)
    rows = [f"{i}\t{n}" for i, n in ans.get("apps", []) + ans.get("games", []) if re.fullmatch(r"[A-Za-z0-9._-]+", i)]
    if rows:
        (q / "pending-apps").write_text("\n".join(rows) + "\n")
    st = [f"{i}\t{n}" for i, n in ans.get("steamGames", []) if re.fullmatch(r"[a-z0-9-]+", i)]
    if st:
        (q / "pending-games").write_text("\n".join(st) + "\n")
    if ans.get("ai") and re.fullmatch(r"[a-z0-9._:-]+", ans["ai"]):
        (q / "ai-model").write_text(ans["ai"] + "\n")
        run(["pacman", "-Sy", "--needed", "--noconfirm", "ollama"], chroot=True, check=False)
        run(["systemctl", "enable", "ollama.service"], chroot=True, check=False)
    # «Mis cosas de Windows»: se copian al disco y el asistente las pasa al primer inicio
    src = None
    for root in ([data_dir.parent] if data_dir else []) + [Path("/run/quantum-datos")]:
        if (root / "Quantum - Mis cosas de Windows" / "manifest.json").is_file():
            src = root / "Quantum - Mis cosas de Windows"
            break
    if ans.get("migrate") and src:
        dst = q / "migrate" / "Quantum - Mis cosas de Windows"
        total = sum(f.stat().st_size for f in src.rglob("*") if f.is_file()) or 1
        doneb = 0
        for f in src.rglob("*"):
            r = dst / f.relative_to(src)
            if f.is_dir():
                r.mkdir(parents=True, exist_ok=True)
            elif f.is_file():
                r.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, r)
                doneb += f.stat().st_size
                progress(0.4 + 0.6 * doneb / total, "Copiando tus cosas de Windows")
        run(["chown", "-R", f"{login}:{login}", "/var/lib/quantum/migrate"], chroot=True)


def cleanup():
    run(["sync"], check=False)
    run(["umount", "-R", str(TARGET)], check=False)


# ------------------------------------------------------------------ principal

def main():
    global done_weight, current
    path = Path(sys.argv[1])
    dry = "--dry-run" in sys.argv
    ans = json.loads(path.read_text())
    if ans.get("format") != 1:
        raise SystemExit("Formato de respuestas desconocido")
    if not Path("/sys/firmware/efi").is_dir():
        emit(step="disk", state="error", percent=0, detail="Este PC arrancó en modo antiguo (BIOS): la instalación automática necesita UEFI")
        return 2
    emit(steps=[{"key": k, "title": t} for k, t, _ in STEPS])
    login, dev, parts = None, None, None
    try:
        for key, title, w in STEPS:
            current = key
            emit(step=key, state="running", percent=round(100 * done_weight / sum(x for _, _, x in STEPS), 1), detail="")
            if key == "disk":
                dev, parts = partition(ans, dry)
                if dry:
                    emit(step=key, state="ok", percent=100, detail=f"Prueba: se instalaría en {dev}")
                    return 0
                format_and_mount(dev, parts)
            elif key == "copy":
                unpack()
            elif key == "system":
                configure(ans)
            elif key == "user":
                login = create_user(ans)
            elif key == "boot":
                bootloader(ans, parts[3], path.parent)
            elif key == "extras":
                extras(ans, login, path.parent)
            done_weight += w
            emit(step=key, state="ok", percent=round(100 * done_weight / sum(x for _, _, x in STEPS), 1), detail="")
    except Exception as e:  # se informa y se deja el disco desmontado
        emit(step=current, state="error", percent=0, detail=str(e))
        cleanup()
        return 1
    cleanup()
    finish_usb(path)
    emit(step="done", state="ok", percent=100, detail="")
    return 0


def finish_usb(answers):
    """Quantum ya quedó instalado: el pendrive no debe volver a arrancar primero ni instalar otra vez."""
    # la entrada de arranque que creó el instalador de Windows
    out = subprocess.run(["efibootmgr"], capture_output=True, text=True).stdout
    for m in re.finditer(r"^Boot([0-9A-Fa-f]{4})\*?\s+Quantum Linux \(instalaci", out, re.M):
        subprocess.run(["efibootmgr", "-q", "-b", m.group(1), "-B"], check=False)
    # las respuestas se renombran (el pendrive está montado de solo lectura)
    mnt = subprocess.run(["findmnt", "-n", "-o", "TARGET", "--target", str(answers)], capture_output=True, text=True).stdout.strip()
    if mnt and subprocess.run(["mount", "-o", "remount,rw", mnt], check=False).returncode == 0:
        try:
            Path(answers).rename(Path(answers).with_name("answers.usado.json"))
        except OSError:
            pass
        subprocess.run(["mount", "-o", "remount,ro", mnt], check=False)


if __name__ == "__main__":
    sys.exit(main())
