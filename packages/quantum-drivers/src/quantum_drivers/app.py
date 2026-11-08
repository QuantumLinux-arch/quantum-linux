"""Drivers: revisa la tarjeta gráfica y, si es una NVIDIA sin su driver, lo instala con un clic.

Uso: quantum-drivers            la ventana
     quantum-drivers --check    si hace falta un driver, avisa con una notificación (al iniciar sesión)
     quantum-drivers --now      abre la ventana solo si hace falta un driver (al terminar la bienvenida)
Desarrollo: QUANTUM_DRIVERS_DEMO="10de:2484 nouveau" finge una NVIDIA y simula la instalación.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

from PyQt6.QtCore import QObject, QProcess, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine

from .detect import gpus

HERE = Path(__file__).resolve().parent
DEMO = bool(os.environ.get("QUANTUM_DRIVERS_DEMO"))
HELPER = "/usr/lib/quantum/drivers/install-nvidia"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "quantum"
DISMISSED = STATE / "drivers-mas-tarde"


class Drivers(QObject):
    changed = pyqtSignal()
    colorsChanged = pyqtSignal()
    jobChanged = pyqtSignal()

    def __init__(self):
        super().__init__()
        self._info = gpus()
        self._colors, self._serp = {}, False
        self._step, self._stepText, self._job = 0, "", ""      # job: "" | running | done | error
        self._proc = None
        self._load_colors()
        QTimer(self, interval=1500, timeout=self._load_colors).start()

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

    @pyqtProperty("QVariant", notify=changed)
    def info(self): return self._info

    @pyqtProperty(int, notify=jobChanged)
    def step(self): return self._step

    @pyqtProperty(str, notify=jobChanged)
    def stepText(self): return self._stepText

    @pyqtProperty(str, notify=jobChanged)
    def job(self): return self._job

    def _set(self, step, text, job=None):
        self._step, self._stepText = step, text
        if job is not None:
            self._job = job
        self.jobChanged.emit()

    @pyqtSlot()
    def install(self):
        g = next((x for x in self._info["gpus"] if x["needs"]), None)
        if not g or self._job == "running":
            return
        self._set(1, "Descargando el driver", "running")
        if DEMO:
            for i, (k, t) in enumerate([(2, "Preparándolo para tu sistema"), (3, "Activándolo"), (4, "Listo")]):
                QTimer.singleShot(1800 * (i + 1), lambda k=k, t=t: self._set(k, t, "done" if k == 4 else None))
            return
        p = QProcess(self)
        self._proc = p
        p.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)

        self._out = []

        def read():
            for line in bytes(p.readAll()).decode(errors="ignore").splitlines():
                self._out.append(line)
                m = re.match(r"PASO (\d) (.+)", line.strip())
                if m:
                    self._set(int(m.group(1)), m.group(2))
                elif line.startswith("ERROR"):
                    self._stepText = line[6:]

        def done(code, _status):
            read()
            if code == 0 and self._step >= 4:
                self._set(4, "Listo", "done")
            elif code in (126, 127):
                self._set(0, "", "")
            else:
                self._set(self._step, explain(self._out, self._stepText), "error")
        p.readyRead.connect(read)
        p.finished.connect(done)
        if g["aur"]:
            # drivers antiguos: se compilan desde el AUR con yay (como Quantum Store) y después lo de root
            pk = " ".join(g["pkgs"])
            # primero se quita el driver abierto (choca con el antiguo y yay con --noconfirm no lo reemplaza)
            p.start("sh", ["-c", f"pkexec {HELPER} clean && echo 'PASO 1 Descargando el driver' && "
                                 f"yay -S --needed --noconfirm --answerdiff None "
                                 f"--answerclean None --removemake --sudo pkexec --sudoflags '' linux-zen-headers {pk} "
                                 f"&& pkexec {HELPER} post"])
        else:
            p.start("pkexec", [HELPER, "open"])

    @pyqtSlot()
    def later(self):
        STATE.mkdir(parents=True, exist_ok=True)
        DISMISSED.touch()
        QGuiApplication.quit()

    @pyqtSlot()
    def reboot(self):
        if not DEMO:
            QProcess.startDetached("systemctl", ["reboot"])

    @pyqtSlot()
    def reset(self):
        self._set(0, "", "")


LOG = Path.home() / ".local/state/quantum/drivers.log"


def explain(out, last):
    """Mensaje claro según lo que pasó, y deja el registro completo en ~/.local/state/quantum/drivers.log."""
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        LOG.write_text("\n".join(out[-400:]) + "\n")
    except OSError:
        pass
    text = "\n".join(out).lower()
    if any(k in text for k in ("could not resolve", "failed to connect", "couldn't resolve", "network is unreachable",
                               "timed out", "no route to host", "temporary failure in name resolution")):
        return "No hay conexión a internet. Conéctate e inténtalo de nuevo."
    if "in conflict" in text or "conflicting" in text:
        return "Otro driver de NVIDIA instalado choca con este. Inténtalo de nuevo; si sigue, reporta el problema desde Ayuda."
    if "dkms" in text and ("error" in text or "failed" in text) or "failed to build" in text or "error making" in text or "a failure occurred" in text:
        return "No se pudo compilar el driver para tu sistema. Actualiza Quantum, reinicia e inténtalo de nuevo."
    if "not enough free disk space" in text or "no space left" in text:
        return "No hay espacio suficiente en el disco."
    if last and last not in ("Descargando el driver", "Quitando el driver que no sirve para tu tarjeta"):
        return last[:1].upper() + last[1:] + "."
    return "No se pudo instalar el driver."


def check():
    """Al iniciar sesión: si hace falta un driver (y no se dijo «más tarde»), una notificación."""
    info = gpus()
    if not info["needs"] or info["vm"] or DISMISSED.exists():
        return 0
    g = next(x for x in info["gpus"] if x["needs"])
    r = subprocess.run(["notify-send", "-a", "Quantum", "-i", "quantum-drivers", "-A", "instalar=Instalar el driver",
                        "Tu tarjeta NVIDIA puede rendir mucho más",
                        f"{g['name']} está usando un driver básico. Con el de NVIDIA, tus juegos van mucho mejor."],
                       capture_output=True, text=True)
    if r.stdout.strip() == "instalar":
        os.execvp(sys.argv[0], [sys.argv[0]])
    return 0


def main():
    if "--check" in sys.argv:
        return check()
    if "--now" in sys.argv:
        info = gpus()
        if not info["needs"] or info["vm"]:
            return 0
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Drivers")
    app.setDesktopFileName("quantum-drivers")
    app.setWindowIcon(QIcon.fromTheme("quantum-drivers", QIcon(str(HERE / "assets" / "quantum-drivers.svg"))))
    dr = Drivers()
    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    ctx.setContextProperty("drivers", dr)
    ctx.setContextProperty("assetsDir", QUrl.fromLocalFile(str(HERE / "assets")).toString())
    engine.warnings.connect(lambda ws: [print("QML:", w.toString(), file=sys.stderr) for w in ws])
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        return 1
    return app.exec()
