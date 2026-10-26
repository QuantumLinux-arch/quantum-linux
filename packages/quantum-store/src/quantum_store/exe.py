"""quantum-exe: abre programas de Windows (.exe / .msi) con Wine, con una ventana que explica qué esperar.

Uso: quantum-exe ARCHIVO
Wine usa su propio prefijo en ~/.local/share/quantum/wine para no mezclar programas con otras herramientas.
"""
import json
import os
import shutil
import sys
from pathlib import Path

from PyQt6.QtCore import QObject, QProcess, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QFont, QFontDatabase, QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine

from .app import IconProvider

HERE = Path(__file__).resolve().parent
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "quantum" / "exe.json"
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "quantum"
PREFIX = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "quantum" / "wine"
INSTALLER_WORDS = ("setup", "install", "instalar", "installer", "instalador")


def load_prefs():
    try:
        return json.loads(CONFIG.read_text())
    except (OSError, ValueError):
        return {}


def wine_env():
    env = dict(os.environ)
    env["WINEPREFIX"] = str(PREFIX)
    env.setdefault("WINEDEBUG", "-all")
    return env


def run_with_wine(path: Path):
    """Lanza el programa (sin esperar) con el prefijo de Quantum."""
    args = ["msiexec", "/i", str(path)] if path.suffix.lower() == ".msi" else ["start", "/unix", str(path)]
    proc = QProcess()
    pe = proc.processEnvironment()
    for k, v in wine_env().items():
        pe.insert(k, v)
    proc.setProcessEnvironment(pe)
    proc.setProgram("wine")
    proc.setArguments(args)
    proc.setWorkingDirectory(str(path.parent))
    proc.startDetached()


class Exe(QObject):
    stateChanged = pyqtSignal()

    def __init__(self, path: Path):
        super().__init__()
        self.path = path
        self._state = "ask"          # ask | installing | preparing | done | error
        self._line = ""
        self._colors = {}
        try:
            self._colors = json.loads((STATE / "colors.json").read_text())
        except (OSError, ValueError):
            pass

    @pyqtProperty(str, constant=True)
    def fileName(self): return self.path.name

    @pyqtProperty(bool, constant=True)
    def installer(self):
        n = self.path.name.lower()
        return self.path.suffix.lower() == ".msi" or any(w in n for w in INSTALLER_WORDS)

    @pyqtProperty(bool, notify=stateChanged)
    def hasWine(self): return shutil.which("wine") is not None

    @pyqtProperty(str, notify=stateChanged)
    def state(self): return self._state

    @pyqtProperty(str, notify=stateChanged)
    def line(self): return self._line

    @pyqtProperty("QVariant", constant=True)
    def colors(self): return self._colors

    def _set(self, state, line=""):
        self._state, self._line = state, line
        self.stateChanged.emit()

    def _proc(self, cmd, env=None, then=None, fail="Algo salió mal"):
        p = QProcess(self)
        p.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        if env:
            pe = p.processEnvironment()
            for k, v in env.items():
                pe.insert(k, v)
            p.setProcessEnvironment(pe)

        def out():
            text = bytes(p.readAll()).decode(errors="ignore").strip().splitlines()
            if text:
                self._line = text[-1][-80:]
                self.stateChanged.emit()

        def done(code, _):
            if code == 0 and then:
                then()
            elif code != 0:
                self._set("error", fail)
        p.readyRead.connect(out)
        p.finished.connect(done)
        p.start(cmd[0], cmd[1:])

    @pyqtSlot(bool)
    def open(self, remember):
        if remember:
            CONFIG.parent.mkdir(parents=True, exist_ok=True)
            CONFIG.write_text(json.dumps({**load_prefs(), "ask": False}))
        if not self.hasWine:
            self._set("installing", "Instalando Wine…")
            self._proc(["pkexec", "pacman", "-S", "--needed", "--noconfirm", "wine", "wine-mono", "wine-gecko"],
                       then=self._prepare, fail="No se pudo instalar Wine")
            return
        self._prepare()

    def _prepare(self):
        self.stateChanged.emit()
        if (PREFIX / "system.reg").exists():
            return self._launch()
        # primera vez: crear el prefijo de Wine (tarda unos segundos)
        PREFIX.parent.mkdir(parents=True, exist_ok=True)
        self._set("preparing", "Preparando Wine por primera vez…")
        self._proc(["wineboot", "-u"], env=wine_env(), then=self._launch, fail="No se pudo preparar Wine")

    def _launch(self):
        run_with_wine(self.path)
        self._set("done")
        QTimer.singleShot(2500, QGuiApplication.quit)

    @pyqtSlot()
    def searchStore(self):
        name = self.path.stem.split("_")[0].split("-")[0].replace("Setup", "").replace("setup", "").strip()
        QProcess.startDetached("quantum-store", ["--search", name or self.path.stem])
        QGuiApplication.quit()


def main():
    if len(sys.argv) < 2:
        print("Uso: quantum-exe ARCHIVO.exe", file=sys.stderr)
        return 2
    path = Path(sys.argv[1].replace("file://", "")).resolve()
    if not path.is_file():
        print(f"No existe: {path}", file=sys.stderr)
        return 1

    # «Abrir siempre sin preguntar»
    if load_prefs().get("ask") is False and shutil.which("wine") and (PREFIX / "system.reg").exists():
        app = QGuiApplication(sys.argv[:1])
        run_with_wine(path)
        return 0

    app = QGuiApplication(sys.argv[:1])
    app.setApplicationName("quantum-exe")
    app.setDesktopFileName("quantum-exe")
    QIcon.setThemeName(os.environ.get("QUANTUM_ICON_THEME", "Papirus-Dark"))
    if "Inter" in QFontDatabase.families():
        app.setFont(QFont("Inter", 10))
    exe = Exe(path)
    engine = QQmlApplicationEngine()
    engine.addImageProvider("icon", IconProvider())
    # Theme.qml lee los colores desde «store.colors»
    engine.rootContext().setContextProperty("store", exe)
    engine.rootContext().setContextProperty("exe", exe)
    engine.warnings.connect(lambda ws: [print("QML:", w.toString(), file=sys.stderr) for w in ws])
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Exe.qml")))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
