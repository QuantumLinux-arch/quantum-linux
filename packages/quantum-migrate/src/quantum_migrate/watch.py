"""Detector en segundo plano (quantum-migrate --watch, lo arranca la sesión).

- Monta los pendrives al conectarlos (como en Windows), así aparecen en Archivos.
- Si un pendrive trae «Quantum - Mis cosas de Windows» que todavía no se pasó, abre el asistente.
No hace nada en el sistema en vivo (el ISO): ahí todavía no hay dónde pasar las cosas.
"""
import json
import os
import subprocess
import time
from pathlib import Path

from . import importer as I

RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))


def usb_partitions():
    """Particiones de discos conectados por USB: [(ruta, ¿montada?)]."""
    code, out = I.run(["lsblk", "-J", "-o", "PATH,FSTYPE,MOUNTPOINT,HOTPLUG,RM,TYPE"])
    if code != 0:
        return []
    res = []

    def walk(d, hot):
        hot = hot or bool(d.get("hotplug")) or bool(d.get("rm"))
        if hot and d.get("fstype") in ("vfat", "exfat", "ntfs", "ext4", "btrfs", "f2fs") and d.get("type") in ("part", "disk"):
            res.append((d["path"], bool(d.get("mountpoint"))))
        for c in d.get("children", []) or []:
            walk(c, hot)
    try:
        for d in json.loads(out).get("blockdevices", []):
            walk(d, False)
    except ValueError:
        pass
    return res


def gui_open():
    """¿Ya está abierto el asistente? (el detector también es «quantum_migrate», pero con --watch)"""
    code, out = I.run(["pgrep", "-af", "quantum_migrat[e]|quantum-migrat[e]"])
    return any("--watch" not in l and "pgrep" not in l for l in out.splitlines()) if code == 0 else False


def main():
    if Path("/run/archiso").exists():
        return 0
    tried, offered = set(), set()
    while True:
        parts = usb_partitions()
        # si se desconecta y se vuelve a conectar, se intenta montar otra vez
        tried &= {p for p, _ in parts}
        for dev, mounted in parts:
            if not mounted and dev not in tried:
                tried.add(dev)
                # el usuario activo puede montar discos extraíbles sin contraseña (polkit)
                I.run(["udisksctl", "mount", "-b", dev, "--no-user-interaction"], timeout=30)
        done = I.done_ids()
        for base, m in I.find_exports():
            mid = m.get("id", "")
            if mid and mid not in done and mid not in offered and not gui_open():
                offered.add(mid)
                subprocess.Popen(["quantum-migrate", "--found", str(base)], start_new_session=True,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(3)
