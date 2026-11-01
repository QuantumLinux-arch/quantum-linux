"""Cronos: la máquina del tiempo de Quantum Linux (PyQt6 + QML).

Muestra los puntos de restauración que guarda Snapper (antes y después de cada actualización,
la instalación y los que guardas a mano) como una línea de tiempo, y vuelve el sistema a
cualquiera de ellos. Tus archivos personales (/home) no cambian.

Variables para desarrollo:
  QUANTUM_CRONOS_DEMO=1        momentos de ejemplo y viaje simulado (no toca nada)
  QUANTUM_CRONOS_SCREENSHOT=a.png  guarda una captura y sale
"""
import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path

from PyQt6.QtCore import QObject, QProcess, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine

HERE = Path(__file__).resolve().parent
DEMO = bool(os.environ.get("QUANTUM_CRONOS_DEMO"))
HELPER = "/usr/lib/quantum/cronos/restore"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "quantum"
MONTHS = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre",
          "octubre", "noviembre", "diciembre"]
DAYS = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]


def when(date):
    """«Hoy, 13:02», «Ayer, 21:40», «Jueves 29 de octubre, 10:15»."""
    today = dt.date.today()
    hm = date.strftime("%H:%M")
    if date.date() == today:
        return f"Hoy, {hm}"
    if date.date() == today - dt.timedelta(days=1):
        return f"Ayer, {hm}"
    d = f"{DAYS[date.weekday()].capitalize()} {date.day} de {MONTHS[date.month - 1]}"
    if date.year != today.year:
        d += f" de {date.year}"
    return f"{d}, {hm}"


def ago(date):
    s = (dt.datetime.now() - date).total_seconds()
    if s < 3600:
        return "hace un rato"
    if s < 86400:
        h = int(s // 3600)
        return f"hace {h} hora{'s' if h > 1 else ''}"
    d = int(s // 86400)
    return f"hace {d} día{'s' if d > 1 else ''}"


def packages_text(pk):
    if not pk:
        return ""
    if len(pk) <= 3:
        return ", ".join(pk[:-1]) + (" y " if len(pk) > 1 else "") + pk[-1]
    return f"{pk[0]}, {pk[1]} y {len(pk) - 2} más"


def moments(snaps):
    """Lista de Snapper → momentos a los que se puede volver (el más nuevo primero)."""
    by_pre = {s.get("pre-number"): s for s in snaps if s.get("type") == "post"}
    out = []
    for s in snaps:
        n = int(s.get("number", 0))
        if n == 0 or s.get("type") == "post":
            continue
        try:
            date = dt.datetime.strptime(s["date"][:19], "%Y-%m-%d %H:%M:%S")
        except (KeyError, ValueError):
            continue
        desc = (s.get("description") or "").strip()
        important = "important=yes" in json.dumps(s.get("userdata") or {}) or (s.get("userdata") or {}).get("important") == "yes"
        kind, title, detail = "save", desc or "Punto guardado", ""
        if s.get("type") == "pre":
            post = by_pre.get(n)
            pk = (post.get("description") or "").split() if post else []
            cmd = desc
            if re.search(r"-S\w*u|-Syu|quantum-update|-Su", cmd):
                kind, title = "update", "Antes de la actualización"
            elif re.search(r"\s-R", cmd):
                kind, title = "remove", "Antes de quitar " + (pk[0] if len(pk) == 1 else "programas")
            elif re.search(r"\s-U|\s-S", cmd):
                kind, title = "install", "Antes de instalar " + (pk[0] if len(pk) == 1 else "programas")
            else:
                kind, title = "update", "Antes de un cambio en el sistema"
            detail = packages_text(pk) + (f" ({len(pk)} paquetes)" if len(pk) > 3 else "")
        elif "Instalación" in desc:
            kind, title, detail = "origin", "Quantum recién instalado", "Como el primer día"
        elif "Cronos" in desc and "Antes" in desc:
            kind, title, detail = "jump", "Antes de un viaje con Cronos", "Para deshacer un viaje"
        elif desc:
            kind, detail = "save", "Guardado a mano"
        out.append({"number": n, "kind": kind, "title": title, "detail": detail, "when": when(date),
                    "ago": ago(date), "important": important, "ts": date.timestamp()})
    out.sort(key=lambda m: -m["ts"])
    return out


def demo_snaps():
    now = dt.datetime.now()
    f = lambda d: (now - d).strftime("%Y-%m-%d %H:%M:%S")
    H, D = dt.timedelta(hours=1), dt.timedelta(days=1)
    return [
        {"number": 1, "type": "single", "date": f(12 * D), "description": "Instalación limpia de Quantum Linux", "userdata": {"important": "yes"}},
        {"number": 2, "type": "pre", "date": f(9 * D), "description": "pacman -S steam"},
        {"number": 3, "type": "post", "pre-number": 2, "date": f(9 * D), "description": "steam lib32-mesa lib32-vulkan-radeon"},
        {"number": 4, "type": "pre", "date": f(5 * D + 3 * H), "description": "pacman -Syu"},
        {"number": 5, "type": "post", "pre-number": 4, "date": f(5 * D + 3 * H), "description": "linux-zen mesa firefox quantum-shell " + " ".join(f"p{i}" for i in range(19)),
         "userdata": {"important": "yes"}},
        {"number": 6, "type": "single", "date": f(3 * D), "description": "Guardado con Cronos"},
        {"number": 7, "type": "pre", "date": f(1 * D + 2 * H), "description": "pacman -S obs-studio"},
        {"number": 8, "type": "post", "pre-number": 7, "date": f(1 * D + 2 * H), "description": "obs-studio"},
        {"number": 9, "type": "pre", "date": f(2 * H), "description": "pacman -Syu"},
        {"number": 10, "type": "post", "pre-number": 9, "date": f(2 * H), "description": "nvidia-utils kitty quantum-cronos wayfire " + " ".join(f"q{i}" for i in range(8))},
    ]


class Cronos(QObject):
    changed = pyqtSignal()
    colorsChanged = pyqtSignal()
    travelChanged = pyqtSignal()
    toast = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self._moments, self._status = [], "loading"      # loading | ready | unsupported | error
        self._step, self._stepText, self._travel = 0, "", ""   # travel: "" | running | done | error
        self._colors, self._serp = {}, False
        self._proc = None
        self._load_colors()
        QTimer(self, interval=1500, timeout=self._load_colors).start()
        QTimer.singleShot(0, self.refresh)

    # ------------------------------------------------------------- colores
    def _load_colors(self):
        try:
            c = json.loads((STATE / "colors.json").read_text())
        except (OSError, ValueError):
            c = {}
        try:
            serp = json.loads((CONFIG / "quantum" / "settings.json").read_text()).get("ui", {}).get("shell") == "serpantium"
        except (OSError, ValueError):
            serp = False
        if c != self._colors or serp != self._serp:
            self._colors, self._serp = c, serp
            self.colorsChanged.emit()

    @pyqtProperty("QVariant", notify=colorsChanged)
    def colors(self): return self._colors

    @pyqtProperty(bool, notify=colorsChanged)
    def serp(self): return self._serp

    # ------------------------------------------------------------ momentos
    @pyqtProperty("QVariant", notify=changed)
    def moments(self): return self._moments

    @pyqtProperty(str, notify=changed)
    def status(self): return self._status

    @pyqtSlot()
    def refresh(self):
        if DEMO:
            self._moments, self._status = moments(demo_snaps()), "ready"
            self.changed.emit()
            return
        root = subprocess.run(["findmnt", "-no", "FSTYPE", "/"], capture_output=True, text=True).stdout.strip()
        if root != "btrfs":
            self._status = "unsupported"
            self.changed.emit()
            return
        r = subprocess.run(["snapper", "--jsonout", "-c", "root", "list",
                            "--columns", "number,type,pre-number,date,description,userdata,cleanup"],
                           capture_output=True, text=True, env={**os.environ, "LANG": "C"})
        try:
            data = json.loads(r.stdout)
            snaps = data.get("root", next(iter(data.values()), []))
            self._moments, self._status = moments(snaps), "ready"
        except (ValueError, StopIteration):
            self._status = "error"
            print("cronos: snapper falló:", r.stderr.strip(), file=sys.stderr)
        self.changed.emit()

    @pyqtSlot()
    def saveNow(self):
        """Guarda el momento actual (sin contraseña: el grupo wheel puede crear puntos)."""
        if DEMO:
            self.toast.emit("Guardé este momento")
            return
        r = subprocess.run(["snapper", "-c", "root", "create", "--description", "Guardado con Cronos",
                            "--cleanup-algorithm", "number"], capture_output=True, text=True)
        if r.returncode != 0:
            r = subprocess.run(["pkexec", "snapper", "-c", "root", "create", "--description", "Guardado con Cronos",
                                "--cleanup-algorithm", "number"], capture_output=True, text=True)
        self.toast.emit("Guardé este momento" if r.returncode == 0 else "No pude guardar este momento")
        self.refresh()

    # ------------------------------------------------------------- el viaje
    @pyqtProperty(int, notify=travelChanged)
    def step(self): return self._step

    @pyqtProperty(str, notify=travelChanged)
    def stepText(self): return self._stepText

    @pyqtProperty(str, notify=travelChanged)
    def travel(self): return self._travel

    def _set(self, step, text, travel=None):
        self._step, self._stepText = step, text
        if travel is not None:
            self._travel = travel
        self.travelChanged.emit()

    @pyqtSlot(int)
    def travelTo(self, n):
        if self._travel == "running":
            return
        self._set(0, "Abriendo el portal…", "running")
        if DEMO:
            steps = [(1, "Guardando el presente"), (2, "Volviendo en el tiempo"), (3, "Preparando el arranque"), (4, "Listo")]
            for i, (k, t) in enumerate(steps):
                QTimer.singleShot(1600 * (i + 1), lambda k=k, t=t: self._set(k, t, "done" if k == 4 else None))
            return
        p = QProcess(self)
        self._proc = p
        p.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)

        def read():
            for line in bytes(p.readAll()).decode(errors="ignore").splitlines():
                m = re.match(r"PASO (\d) (.+)", line.strip())
                if m:
                    self._set(int(m.group(1)), m.group(2))
                elif line.startswith("ERROR"):
                    self._stepText = line[6:]

        def done(code, _status):
            read()
            if code == 0 and self._step >= 4:
                self._set(4, "Listo", "done")
            elif code in (126, 127):     # se cerró la ventana de la contraseña
                self._set(0, "", "")
                self.toast.emit("No escribiste la contraseña: no cambió nada")
            else:
                self._set(self._step, self._stepText or "Algo salió mal", "error")
            self.refresh()
        p.readyRead.connect(read)
        p.finished.connect(done)
        p.start("pkexec", [HELPER, str(n)])

    @pyqtSlot()
    def resetTravel(self):
        self._set(0, "", "")

    @pyqtSlot()
    def reboot(self):
        if DEMO:
            self.toast.emit("[demostración] aquí se reiniciaría el PC")
            return
        QProcess.startDetached("systemctl", ["reboot"])


def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Cronos")
    app.setDesktopFileName("quantum-cronos")
    app.setWindowIcon(QIcon.fromTheme("quantum-cronos", QIcon(str(HERE / "assets" / "quantum-cronos.svg"))))
    cr = Cronos()
    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    ctx.setContextProperty("cronos", cr)
    ctx.setContextProperty("demoMode", DEMO)
    ctx.setContextProperty("shotPath", os.environ.get("QUANTUM_CRONOS_SCREENSHOT", ""))
    ctx.setContextProperty("assetsDir", QUrl.fromLocalFile(str(HERE / "assets")).toString())
    engine.warnings.connect(lambda ws: [print("QML:", w.toString(), file=sys.stderr) for w in ws])
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        sys.exit(1)
    # captura para revisar el diseño; QUANTUM_CRONOS_TRAVEL=1 la toma a mitad de un viaje (demo)
    shot = os.environ.get("QUANTUM_CRONOS_SCREENSHOT")
    if shot:
        win = engine.rootObjects()[0]
        if os.environ.get("QUANTUM_CRONOS_TRAVEL"):
            QTimer.singleShot(800, lambda: cr.travelTo(9))
        QTimer.singleShot(int(os.environ.get("QUANTUM_CRONOS_SHOT_MS", "2500")), lambda: (win.grabWindow().save(shot), app.quit()))
    sys.exit(app.exec())
