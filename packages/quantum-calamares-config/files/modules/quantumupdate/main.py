#!/usr/bin/env python3
"""Instalador de Quantum Linux: deja el sistema nuevo en la última versión.

El ISO puede ser de hace semanas; si hay internet, aquí se baja lo nuevo (paquetes de Arch y
del repo [quantum]) antes de terminar, así la persona arranca ya actualizada.

  1. Llavero de Arch primero (un ISO viejo puede no conocer las firmas nuevas).
  2. Descarga de todo (pacman -Syuw): se muestra el avance y, si tarda demasiado, se corta
     sin riesgo (todavía no se cambió nada).
  3. Instalación desde lo descargado (pacman -Su): rápida y sin internet; no se interrumpe.
  4. Se vacía la caché de paquetes para no ocupar espacio.

Si no hay internet o algo falla, se sigue con la instalación normal: el sistema queda
como venía en el ISO y se actualiza después con «Actualizar».
"""
import os
import re
import select
import subprocess
import time
import urllib.request

import libcalamares

DOWNLOAD_TIMEOUT = 25 * 60      # segundos para bajar todo antes de dejarlo para después
status = "Buscando actualizaciones"


def pretty_name():
    return "Actualizando a la última versión"


def pretty_status_message():
    return status


def online():
    for url in ("https://geo.mirror.pkgbuild.com/", "https://archlinux.org/"):
        try:
            urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=6)
            return True
        except Exception:
            continue
    return False


def pacman(root, args, on_line=None, timeout=None):
    """pacman dentro del sistema nuevo, leyendo su salida línea por línea."""
    p = subprocess.Popen(["chroot", root] + args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         env=dict(os.environ, LANG="C", LC_ALL="C"))
    start, buf = time.time(), b""
    tail = []
    while True:
        if timeout and time.time() - start > timeout:
            p.kill()
            p.wait()
            return -1, tail
        r, _, _ = select.select([p.stdout], [], [], 1.0)
        if r:
            chunk = os.read(p.stdout.fileno(), 8192)
            if not chunk:
                break
            buf += chunk
            *lines, buf = re.split(rb"[\r\n]", buf)
            for raw in lines:
                line = raw.decode(errors="ignore").strip()
                if line:
                    tail = (tail + [line])[-8:]
                    if on_line:
                        on_line(line)
        elif p.poll() is not None:
            break
    p.wait()
    return p.returncode, tail


def clean_cache(root):
    """Borra los paquetes descargados (pacman -Scc preguntaría; aquí no hay a quién)."""
    subprocess.run(["chroot", root, "sh", "-c", "rm -f /var/cache/pacman/pkg/*.pkg.tar.* /var/cache/pacman/pkg/*.sig"],
                   capture_output=True)


def run():
    global status
    root = libcalamares.globalstorage.value("rootMountPoint")
    if not root or not os.path.isdir(root):
        return None
    if not online():
        libcalamares.utils.debug("quantumupdate: sin internet; se deja para después")
        return None

    libcalamares.job.setprogress(0.02)
    status = "Actualizando las firmas de los paquetes"
    code, tail = pacman(root, ["pacman", "-Sy", "--needed", "--noconfirm", "--noprogressbar",
                            "archlinux-keyring"], timeout=10 * 60)
    if code != 0:
        libcalamares.utils.warning("quantumupdate: no se pudo actualizar el llavero: " + " | ".join(tail))
        return None

    # cuántos paquetes hay para actualizar
    count_proc = subprocess.run(["chroot", root, "pacman", "-Qu"], capture_output=True, text=True)
    total = len([l for l in count_proc.stdout.splitlines() if l.strip()])
    if total == 0:
        status = "Quantum ya está en la última versión"
        libcalamares.job.setprogress(1.0)
        return None

    # 1) descargar todo (se puede cortar sin riesgo)
    state = {"n": 0}
    def on_download(line):
        global status
        m = re.search(r"downloading (\S+)\.pkg\.tar", line) or re.search(r"^(\S+)-[^-]+-[^-]+-\S+\.pkg\.tar\.\w+\s", line)
        if m:
            state["n"] += 1
            status = f"Descargando actualizaciones ({min(state['n'], total)} de {total})"
            libcalamares.job.setprogress(0.05 + 0.65 * min(1.0, state["n"] / total))
    status = f"Descargando {total} actualizaciones"
    code, tail = pacman(root, ["pacman", "-Syuw", "--noconfirm", "--noprogressbar"], on_download, DOWNLOAD_TIMEOUT)
    if code != 0:
        libcalamares.utils.warning("quantumupdate: la descarga no terminó; se deja para después: " + " | ".join(tail))
        clean_cache(root)
        return None

    # 2) instalar desde lo descargado (sin internet, no se corta)
    def on_install(line):
        global status
        m = re.match(r"\((\d+)/(\d+)\) (upgrading|installing|reinstalling) (\S+)", line)
        if m:
            i, n = int(m.group(1)), int(m.group(2))
            status = f"Instalando actualizaciones ({i} de {n}): {m.group(4)}"
            libcalamares.job.setprogress(0.72 + 0.26 * i / max(1, n))
    status = "Instalando las actualizaciones"
    code, tail = pacman(root, ["pacman", "-Su", "--noconfirm", "--noprogressbar"], on_install)
    if code != 0:
        libcalamares.utils.warning("quantumupdate: pacman -Su terminó con error: " + " | ".join(tail))
    clean_cache(root)
    status = "Quantum quedó en la última versión"
    libcalamares.job.setprogress(1.0)
    return None
