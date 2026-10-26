"""Fotón: la biblioteca de juegos de Quantum Linux (PyQt6 + QML).

Uso: foton [--tienda]
Para capturas de desarrollo: FOTON_SCREENSHOT=archivo.png
"""
import json
import os
import re
import shutil
import sys
import threading
from pathlib import Path

from PyQt6.QtCore import QObject, QProcess, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QFont, QFontDatabase, QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine

from quantum_store.app import IconProvider, WebImageProvider

from . import library as L

HERE = Path(__file__).resolve().parent


class Foton(QObject):
    gamesChanged = pyqtSignal()
    toolsChanged = pyqtSignal()
    colorsChanged = pyqtSignal()
    storeChanged = pyqtSignal()
    toast = pyqtSignal(str)
    exePicker = pyqtSignal(str, str, "QVariant")     # nombre, prefijo, candidatos
    _bg = pyqtSignal(str, object)
    _tick = pyqtSignal(str)      # avance desde un hilo: «store» o «tools»

    def __init__(self):
        super().__init__()
        self._games, self._colors = [], {}
        self._ge = {"installed": L.proton_ge_installed(), "busy": False, "progress": 0}
        self._catalog = L.catalog()
        self._flatpaks = set()
        self._jobs = {}                 # id del catálogo -> avance (0..1) mientras se instala
        self._pending = L.pending_games()
        self._bg.connect(self._done)
        self._tick.connect(lambda w: (self.storeChanged if w == "store" else self.toolsChanged).emit())
        self._load_colors()
        QTimer(self, interval=1500, timeout=self._load_colors).start()
        # Steam/Heroic pueden instalar juegos mientras Fotón está abierto
        QTimer(self, interval=15000, timeout=self.refresh).start()

    @pyqtProperty("QVariant", notify=gamesChanged)
    def games(self): return self._games

    @pyqtProperty("QVariant", notify=colorsChanged)
    def colors(self): return self._colors

    @pyqtProperty("QVariant", notify=storeChanged)
    def catalog(self):
        """El catálogo con el estado de cada juego: installed | installing | none."""
        steam = {g["id"] for g in self._games if g["source"] == "steam"}
        out = []
        for c in self._catalog:
            inst = c["ref"] in (steam if c["kind"] == "steam" else self._flatpaks)
            key = ("steam:" if c["kind"] == "steam" else "foton:") + c["ref"]
            out.append({**c, "installed": inst, "key": key,
                        "progress": self._jobs.get(c["id"], -1),
                        "pending": c["id"] in self._pending and not inst})
        return out

    @pyqtProperty("QVariant", notify=toolsChanged)
    def tools(self):
        return {"gamemode": L.gamemode_on(), "fps": L.fps_on(), "ge": self._ge,
                "steam": L.steam_root() is not None}

    def _load_colors(self):
        try:
            c = json.loads((L.STATE / "colors.json").read_text())
        except (OSError, ValueError):
            c = {}
        if c != self._colors:
            self._colors = c
            self.colorsChanged.emit()

    def _run(self, tag, fn, *args):
        def work():
            try:
                res = fn(*args)
            except Exception as e:
                res = e
            self._bg.emit(tag, res)
        threading.Thread(target=work, daemon=True).start()

    def _done(self, tag, res):
        if tag == "games" and not isinstance(res, Exception):
            games, flatpaks = res
            if games != self._games:
                self._games = games
                self.gamesChanged.emit()
            self._flatpaks = flatpaks
            self.storeChanged.emit()
        elif tag.startswith("install:"):
            cid = tag[8:]
            self._jobs.pop(cid, None)
            c = next((x for x in self._catalog if x["id"] == cid), {})
            if isinstance(res, Exception):
                self.toast.emit(f"No pude instalar {c.get('name', cid)}. Revisa tu internet.")
            else:
                self.toast.emit(f"{c.get('name', cid)} está listo para jugar")
            self.storeChanged.emit()
            self.refresh()
        elif tag == "winsetup":
            name, (prefix, found) = res if not isinstance(res, Exception) else ("", ("", []))
            if not prefix:
                self.toast.emit("El instalador no terminó bien")
            elif not found:
                self.toast.emit("No encontré el juego instalado. Agrégalo con «Ya está instalado».")
            else:
                self.exePicker.emit(name, prefix, found)
        elif tag == "wingame":
            self.refresh()
        elif tag == "ge":
            self._ge.update(busy=False, progress=0)
            if isinstance(res, Exception):
                self.toast.emit("No pude descargar Proton-GE. Revisa tu internet.")
            else:
                self._ge["installed"] = res
                self.toast.emit(f"{res} listo. Elígelo en Steam: Propiedades → Compatibilidad.")
            self.toolsChanged.emit()

    @pyqtSlot()
    def refresh(self):
        self._run("games", lambda: (L.all_games(lookup=True), L.flatpak_installed()))

    # ------------------------------------------------------------- tienda
    @pyqtSlot(str)
    def install(self, cid):
        c = next((x for x in self._catalog if x["id"] == cid), None)
        if not c or cid in self._jobs:
            return
        if c["kind"] == "steam":
            if L.steam_root() is None and not shutil.which("steam"):
                self.toast.emit("Primero instala Steam desde Quantum Store")
                return
            L.install_steam(c["ref"])
            self.toast.emit(f"Steam va a instalar {c['name']}. Inicia sesión si te lo pide.")
            return
        self._jobs[cid] = 0
        self.storeChanged.emit()

        def prog(x):
            self._jobs[cid] = x
            self._tick.emit("store")
        self._run("install:" + cid, L.install_flatpak, c["ref"], prog)

    # --------------------------------------------------- juegos de Windows
    @pyqtSlot(str, str)
    def addWindowsGame(self, path, name):
        """Un .exe: si parece instalador lo ejecuta en un prefijo nuevo; si no, lo agrega."""
        p = Path(QUrl(path).toLocalFile() if path.startswith("file:") else path)
        name = name.strip() or L.nice_name(p.parent)
        if not p.exists():
            return
        if re.search(r"setup|install|instalar", p.stem, re.I) or p.suffix.lower() == ".msi":
            self.toast.emit(f"Abriendo el instalador de {name}. La primera vez se prepara Proton y puede tardar.")
            self._run("winsetup", lambda: (name, L.run_windows_installer(name, p)))
        else:
            self._run("wingame", L.add_windows_game, name, p)
            self.toast.emit(f"{name} se agregó a tu biblioteca")

    @pyqtSlot(str, str, str)
    def chooseExe(self, name, prefix, exe):
        self._run("wingame", L.add_windows_game, name, exe, prefix)
        self.toast.emit(f"{name} se agregó a tu biblioteca")

    @pyqtSlot(str)
    def removeGame(self, key):
        if key.startswith("windows:"):
            L.remove_windows_game(key[8:])
            self.refresh()

    @pyqtSlot()
    def openGamesFolder(self):
        L.GAMES_DIR.mkdir(exist_ok=True)
        QProcess.startDetached("xdg-open", [str(L.GAMES_DIR)])

    @pyqtSlot(str)
    def play(self, key):
        g = next((x for x in self._games if x["key"] == key), None)
        if not g:
            return
        L.launch(g)
        if g["source"] == "windows" and not (Path.home() / ".local/share/umu").exists():
            self.toast.emit(f"Preparando Proton para {g['name']}: la primera vez tarda unos minutos")
        else:
            self.toast.emit(f"Abriendo {g['name']}…")
        QTimer.singleShot(1500, self.refresh)

    @pyqtSlot(bool)
    def setGamemode(self, on):
        L.set_gamemode(on)
        self.toast.emit("Modo juego activado: sin notificaciones ni efectos" if on else "Modo juego desactivado")
        QTimer.singleShot(600, self.toolsChanged.emit)

    @pyqtSlot(bool)
    def setFps(self, on):
        L.set_fps(on)
        self.toast.emit("Los FPS se verán en los juegos que abras desde aquí y, tras volver a iniciar sesión, en todos"
                        if on else "FPS ocultos")
        self.toolsChanged.emit()

    @pyqtSlot()
    def installGe(self):
        if self._ge["busy"]:
            return
        self._ge.update(busy=True, progress=0)
        self.toolsChanged.emit()

        def prog(x):
            self._ge["progress"] = x
            self._tick.emit("tools")
        self._run("ge", L.install_proton_ge, prog)

    @pyqtSlot(str)
    def open(self, what):
        cmds = {"steam": ["steam"], "heroic": ["quantum-store", "--app", "flathub:com.heroicgameslauncher.hgl"],
                "store": ["quantum-store", "--page", "juegos"]}
        QProcess.startDetached(cmds[what][0], cmds[what][1:])


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("foton")
    app.setDesktopFileName("foton")
    QIcon.setThemeName(os.environ.get("QUANTUM_ICON_THEME", "Papirus-Dark"))
    app.setWindowIcon(QIcon.fromTheme("foton"))
    if "Inter" in QFontDatabase.families():
        app.setFont(QFont("Inter", 10))
    f = Foton()
    f._games = L.all_games()          # primera carga rápida, sin esperar al hilo
    f.refresh()                       # y luego portadas de Windows y estado de la tienda
    engine = QQmlApplicationEngine()
    engine.addImageProvider("icon", IconProvider())
    engine.addImageProvider("web", WebImageProvider())
    engine.rootContext().setContextProperty("foton", f)
    engine.rootContext().setContextProperty("store", f)   # Theme.qml lee store.colors
    tab = "store" if "--tienda" in sys.argv or os.environ.get("FOTON_TAB") == "store" else ""
    engine.rootContext().setContextProperty("startTab", tab)
    # para capturas de desarrollo: FOTON_OPEN=detail:<id> | add, FOTON_SCROLL=<px>, FOTON_SIZE=<an>x<al>
    engine.rootContext().setContextProperty("startOpen", os.environ.get("FOTON_OPEN", ""))
    engine.rootContext().setContextProperty("startScroll", int(os.environ.get("FOTON_SCROLL", "0")))
    engine.warnings.connect(lambda ws: [print("QML:", w.toString(), file=sys.stderr) for w in ws])
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        return 1
    shot = os.environ.get("FOTON_SCREENSHOT")
    if os.environ.get("FOTON_SIZE"):
        w, h = map(int, os.environ["FOTON_SIZE"].split("x"))
        engine.rootObjects()[0].setProperty("width", w)
        engine.rootObjects()[0].setProperty("height", h)
    if shot:
        win = engine.rootObjects()[0]
        QTimer.singleShot(int(os.environ.get("FOTON_WAIT", "3500")),
                          lambda: (win.grabWindow().save(shot), app.quit()))
    return app.exec()
