"""Ayudante de Quarki (el asistente de Quantum Shell): busca, instala y desinstala apps con
las mismas fuentes que Quantum Store, y responde en JSON para que el shell lo muestre.

  python3 -m quantum_store.quarki search "minecraft"     → la mejor opción y alternativas
  python3 -m quantum_store.quarki owner firefox.desktop  → de qué paquete es una app (para desinstalar)
  python3 -m quantum_store.quarki launch flathub com.spotify.Client
"""
import json
import os
import re
import subprocess
import sys
import unicodedata

from .backends import Arch, Aur, Flathub, http_json, run

# Lo que sostiene el escritorio: Quarki no lo desinstala aunque se lo pidan
PROTECTED = re.compile(r"^(quantum-.*|base|base-devel|linux(-zen|-lts)?(-headers)?|linux-firmware.*|systemd.*|glibc|pacman|"
                       r"wayfire.*|quickshell.*|pipewire.*|wireplumber|networkmanager|sddm|mesa|vulkan-.*|polkit|sudo|"
                       r"grub|snapper|btrfs-progs|flatpak|kitty|python|python-pyqt6|qt6-.*|xdg-.*|dbus.*|matugen)$")

LIBRARY = re.compile(r"^(lib|python-|perl-|ruby-|haskell-|lua-|nodejs-|rust-|go-|ttf-|otf-|texlive-)|(-docs?|-devel|-headers|-data|-common)$")


def norm(s):
    s = unicodedata.normalize("NFD", s or "")
    return re.sub(r"[^a-z0-9]+", " ", "".join(c for c in s if unicodedata.category(c) != "Mn").lower()).strip()


def score(it, q):
    """0 = es exactamente eso … 4 = parecido; menos es mejor."""
    name, iid = norm(it["name"]), it["id"].lower()
    last = iid.split(".")[-1]
    qs = q.replace(" ", "")
    if name == q or name.replace(" ", "") == qs or iid == qs or last == qs:
        return 0
    if name.startswith(q) or iid.startswith(qs) or last.startswith(qs):
        return 1
    if q in name or qs in iid:
        return 2
    return 4


def search(q):
    qn = norm(q)
    found = []
    for i, it in enumerate(Arch().search(q, limit=25)):
        if LIBRARY.search(it["id"]):
            continue
        found.append((score(it, qn), 0, i, it))
    try:
        for i, it in enumerate(Flathub().search(q, limit=12)):
            # Flathub ya ordena por relevancia: se respeta ese orden dentro del mismo puntaje
            found.append((min(score(it, qn), 3), 1, i, it))
    except Exception:
        pass   # sin internet: solo lo de Arch (pacman tiene su lista local)
    good = [f for f in found if f[0] <= 3]
    if not good:
        try:
            for i, it in enumerate(Aur().search(q, limit=8)):
                s = score(it, qn)
                if s <= 2:
                    good.append((s + 1, 2, i, it))
        except Exception:
            pass
    good.sort(key=lambda f: (f[0], f[1], f[2]))
    # nombre bonito para los paquetes de Arch: el de Flathub si es la misma app, o con mayúscula
    pretty = {norm(f[3]["name"]).replace(" ", ""): f[3]["name"] for f in good if f[3]["source"] == "flathub"}
    out = []
    for s, _, _, it in good[:4]:
        if it["source"] != "flathub":
            key = it["id"].lower().replace("-", "")
            it = dict(it, name=pretty.get(key) or it["name"][:1].upper() + it["name"][1:])
        src = it["source"]
        back = {"arch": Arch, "flathub": Flathub, "aur": Aur}[src]()
        it = dict(it, exact=s == 0, weak=s >= 3, install=back.install_cmd(it["id"]),
                  sourceLabel={"arch": "Arch Linux", "flathub": "Flathub", "aur": "AUR (comunidad)"}[src])
        if src == "aur":
            it["warning"] = "Lo publica la comunidad y se compila en tu PC: puede tardar varios minutos."
        out.append(it)
    if out:
        out[0]["size"] = size_of(out[0])
    return out


def human(n):
    n = float(n)
    for u in ("B", "KB", "MB", "GB"):
        if n < 1024 or u == "GB":
            return f"{n:.0f} {u}" if u in ("B", "KB") else f"{n:.1f} {u}".replace(".", ",")
        n /= 1024


def size_of(it):
    try:
        if it["source"] == "arch":
            m = re.search(r"^Download Size\s*:\s*([\d.]+)\s*(\w+)", run(["pacman", "-Si", "--", it["id"]]), re.M)
            if not m:
                return ""
            mult = {"B": 1, "KiB": 1024, "MiB": 1024 ** 2, "GiB": 1024 ** 3}.get(m.group(2), 1)
            return human(float(m.group(1)) * mult)
        if it["source"] == "flathub":
            d = http_json(f"{Flathub.API}/summary/{it['id']}", ttl=6 * 3600, cache_name=f"fh-sum-{re.sub(r'[^A-Za-z0-9._-]', '_', it['id'])}.json")
            n = d.get("download_size") or d.get("installed_size")
            return human(n) if n else ""
    except Exception:
        pass
    return ""


def owner(desktop_id):
    """De qué paquete viene una app del menú (para desinstalarla)."""
    did = desktop_id if desktop_id.endswith(".desktop") else desktop_id + ".desktop"
    app = did[:-8]
    flat = run(["flatpak", "list", "--app", "--columns=application,name"])
    for line in flat.splitlines():
        parts = line.split("\t")
        if parts and parts[0] == app:
            return {"source": "flathub", "id": app, "name": parts[1] if len(parts) > 1 else app,
                    "remove": Flathub().remove_cmd(app)}
    for d in (os.path.expanduser("~/.local/share/applications"), "/usr/share/applications", "/usr/local/share/applications"):
        path = os.path.join(d, did)
        if os.path.exists(path):
            pkg = run(["pacman", "-Qqo", path]).strip()
            if not pkg:
                return {"error": "manual", "path": path}
            if PROTECTED.match(pkg):
                return {"error": "protected", "id": pkg}
            info = run(["pacman", "-Qi", pkg])
            req = re.search(r"^Required By\s*:\s*(.+)$", info, re.M)
            req = [] if not req or req.group(1).strip() == "None" else req.group(1).split()
            src = "aur" if pkg in Aur().installed() else "arch"
            return {"source": src, "id": pkg, "name": pkg, "requiredBy": req[:5],
                    "remove": ["pkexec", "pacman", "-Rns", "--noconfirm", pkg]}
    return {"error": "notfound"}


def launch(src, id_):
    if src == "flathub":
        cmd = ["flatpak", "run", id_]
    else:
        desk = [l for l in run(["pacman", "-Qlq", id_]).splitlines() if re.match(r"/usr/share/applications/.*\.desktop$", l)]
        if not desk:
            return 1
        cmd = ["gtk-launch", os.path.basename(desk[0])]
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return 0


def main(argv):
    if len(argv) >= 2 and argv[0] == "search":
        print(json.dumps(search(" ".join(argv[1:])), ensure_ascii=False))
    elif len(argv) == 2 and argv[0] == "owner":
        print(json.dumps(owner(argv[1]), ensure_ascii=False))
    elif len(argv) == 3 and argv[0] == "launch":
        return launch(argv[1], argv[2])
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
