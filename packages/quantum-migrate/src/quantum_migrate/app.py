"""Pasar desde Windows: el asistente que trae a Quantum lo que «Pasar a Quantum.exe» guardó en un pendrive.

Uso: quantum-migrate                abre el asistente (busca el pendrive)
     quantum-migrate --found RUTA   lo abre el detector cuando encuentra un pendrive
     quantum-migrate --preparar     copia «Pasar a Quantum.exe» a un pendrive
     quantum-migrate --watch        detector en segundo plano (monta pendrives y avisa)
Para capturas de desarrollo: MIGRATE_SCREENSHOT=archivo.png [MIGRATE_STATE=…]
"""
import json
import os
import shutil
import subprocess
import sys
import threading
from pathlib import Path

from PyQt6.QtCore import QObject, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QFont, QFontDatabase, QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine

from . import importer as I

HERE = Path(__file__).resolve().parent
EXE = Path(os.environ.get("QUANTUM_MIGRATE_EXE", "/usr/share/quantum/migrate/Pasar a Quantum.exe"))
LIVE = Path("/run/archiso").exists()


def removable_mounts():
    """Pendrives montados (para «Preparar un pendrive»): [{path, name, free}]."""
    code, out = I.run(["lsblk", "-J", "-b", "-o", "PATH,MOUNTPOINT,LABEL,HOTPLUG,RM,FSAVAIL,SIZE,TYPE"])
    res = []
    try:
        devs = json.loads(out).get("blockdevices", [])
    except ValueError:
        return res

    def walk(d, hot):
        hot = hot or d.get("hotplug") or d.get("rm")
        mp = d.get("mountpoint")
        if hot and mp and mp.startswith(("/run/media", "/media", "/mnt")):
            res.append({"path": mp, "name": d.get("label") or Path(mp).name, "free": int(d.get("fsavail") or 0)})
        for c in d.get("children", []) or []:
            walk(c, hot)
    for d in devs:
        walk(d, False)
    extra = os.environ.get("QUANTUM_MIGRATE_ROOTS")
    if extra:
        for p in extra.split(":"):
            if Path(p).is_dir() and all(r["path"] != p for r in res):
                res.append({"path": p, "name": Path(p).name.upper(), "free": shutil.disk_usage(p).free})
    return res


class Migrate(QObject):
    changed = pyqtSignal()
    progressChanged = pyqtSignal()
    colorsChanged = pyqtSignal()
    _bg = pyqtSignal(str, object)
    _stepSig = pyqtSignal(str, str, str)      # desde el hilo de la importación
    _progSig = pyqtSignal(float, str)

    def __init__(self, found=None, start_state=None):
        super().__init__()
        self._state = "buscando"
        self._exports = []
        self._cur = None             # (base, manifest)
        self._summary = {}
        self._choices = {"folders": True, "account": True, "wifi": True, "browsers": True, "steam": True}
        self._apps = {}              # flatpak -> elegido
        self._steps = []
        self._progress = 0.0
        self._ptext = ""
        self._importer = None
        self._drives = []
        self._prep = {"busy": False, "done": "", "error": ""}
        self._running = {"firefox": False, "steam": False}
        self._colors = {}
        self._bg.connect(self._done)
        self._stepSig.connect(self._apply_step)
        self._progSig.connect(self._apply_progress)
        self._load_colors()
        if found:
            self._pick(Path(found))
        else:
            ex = I.find_exports()
            if ex:
                self._pick(ex[0][0])
        if start_state:
            self._state = start_state
        self._scan()
        t = QTimer(self, interval=2000)
        t.timeout.connect(self._tick)
        t.start()

    # --------------------------------------------------------- propiedades
    @pyqtProperty(str, notify=changed)
    def state(self): return self._state

    @pyqtProperty("QVariant", notify=changed)
    def summary(self): return self._summary

    @pyqtProperty("QVariant", notify=changed)
    def choices(self): return self._choices

    @pyqtProperty("QVariant", notify=changed)
    def apps(self):
        return [dict(a, on=self._apps.get(a["flatpak"], False)) for a in self._summary.get("apps", [])]

    @pyqtProperty("QVariant", notify=changed)
    def steps(self): return self._steps

    @pyqtProperty(float, notify=progressChanged)
    def progress(self): return self._progress

    @pyqtProperty(str, notify=progressChanged)
    def progressText(self): return self._ptext

    @pyqtProperty("QVariant", notify=changed)
    def drives(self): return self._drives

    @pyqtProperty("QVariant", notify=changed)
    def prep(self): return self._prep

    @pyqtProperty("QVariant", notify=changed)
    def running(self): return self._running

    @pyqtProperty(bool, constant=True)
    def live(self): return LIVE

    @pyqtProperty(bool, constant=True)
    def hasExe(self): return EXE.is_file()

    @pyqtProperty("QVariant", notify=colorsChanged)
    def colors(self): return self._colors

    # ------------------------------------------------------------- interno
    def _load_colors(self):
        try:
            c = json.loads((I.STATE / "colors.json").read_text())
        except (OSError, ValueError):
            c = {}
        if c != self._colors:
            self._colors = c
            self.colorsChanged.emit()

    def _pick(self, base):
        for b, m in I.find_exports():
            if b == base or not base:
                self._cur = (b, m)
                break
        else:
            try:
                self._cur = (base, json.loads((base / "manifest.json").read_text()))
            except (OSError, ValueError):
                self._cur = None
        if self._cur:
            self._summary = I.summary(*self._cur)
            self._summary["done"] = self._cur[1].get("id") in I.done_ids()
            have = I.installed_flatpaks()
            self._apps = {a["flatpak"]: (a["flatpak"] not in have) for a in self._summary["apps"] if a["flatpak"]}
            for a in self._summary["apps"]:
                a["installed"] = bool(a["flatpak"] and a["flatpak"] in have) or a["flatpak"] is None
            m = self._cur[1]
            self._choices = {"folders": bool(m.get("folders")), "account": bool(m.get("account") or m.get("settings")),
                             "wifi": bool(m.get("wifi")), "browsers": bool(m.get("browsers")), "steam": bool(m.get("steam"))}
            self._state = "encontrado"

    def _scan(self):
        if self._state in ("buscando",):
            ex = I.find_exports()
            if ex:
                self._pick(ex[0][0])
                self.changed.emit()
        if self._state == "preparar":
            d = removable_mounts()
            if d != self._drives:
                self._drives = d
                self.changed.emit()
        r = {"firefox": I.running("firefox"), "steam": I.running("steam")}
        if r != self._running:
            self._running = r
            self.changed.emit()

    def _tick(self):
        self._load_colors()
        if self._state in ("buscando", "preparar", "encontrado", "elegir"):
            self._scan()

    def _done(self, tag, res):
        if tag == "import":
            self._state = "listo"
            self.changed.emit()
        elif tag == "prep":
            self._prep = dict(self._prep, busy=False, **res)
            self.changed.emit()

    # ---------------------------------------------------------------- acciones
    @pyqtSlot(str)
    def go(self, state):
        self._state = state
        if state == "preparar":
            self._drives = removable_mounts()
            self._prep = {"busy": False, "done": "", "error": ""}
        self.changed.emit()

    @pyqtSlot(str, bool)
    def setChoice(self, key, on):
        self._choices = dict(self._choices, **{key: on})
        self.changed.emit()

    @pyqtSlot(str, bool)
    def setApp(self, fid, on):
        self._apps[fid] = on
        self.changed.emit()

    @pyqtSlot()
    def start(self):
        if not self._cur:
            return
        base, m = self._cur
        ch = dict(self._choices, apps=[f for f, on in self._apps.items() if on])
        self._importer = I.Importer(base, m, ch, on_step=self._on_step, on_progress=self._on_progress)
        self._steps = [{"key": k, "title": t, "state": "waiting", "detail": ""} for k, t in self._importer.steps()]
        self._progress, self._ptext = 0.0, ""
        self._state = "pasando"
        self.changed.emit()

        def work():
            self._importer.run()
            self._bg.emit("import", None)
        threading.Thread(target=work, daemon=True).start()

    # el importador avisa desde su hilo: las señales llevan el aviso al hilo de la ventana
    def _on_step(self, key, state, detail):
        self._stepSig.emit(key, state, detail)

    def _on_progress(self, frac, text):
        self._progSig.emit(frac, text)

    def _apply_step(self, key, state, detail):
        self._steps = [dict(s, state=state, detail=detail) if s["key"] == key else s for s in self._steps]
        self.changed.emit()

    def _apply_progress(self, frac, text):
        self._progress, self._ptext = frac, text
        self.progressChanged.emit()

    @pyqtSlot()
    def cancel(self):
        if self._importer:
            self._importer.copier.cancelled = True

    @pyqtSlot()
    def openHome(self):
        subprocess.Popen(["xdg-open", str(I.HOME)])

    @pyqtSlot()
    def deleteWifi(self):
        """Borra las contraseñas Wi-Fi del pendrive (ya quedaron guardadas en Quantum)."""
        if not self._cur:
            return
        base, m = self._cur
        try:
            (base / "wifi.json").unlink(missing_ok=True)
            m["wifi"] = None
            tmp = base / "manifest.json.tmp"
            tmp.write_text(json.dumps(m, indent=2, ensure_ascii=False))
            tmp.replace(base / "manifest.json")
            self._summary = dict(self._summary, wifiDeleted=True)
        except OSError:
            self._summary = dict(self._summary, wifiDeleted=False)
        self.changed.emit()

    @pyqtSlot(str)
    def prepareCopy(self, mount):
        """Copia «Pasar a Quantum.exe» a la raíz del pendrive."""
        if self._prep.get("busy"):
            return
        self._prep = {"busy": True, "done": "", "error": ""}
        self.changed.emit()

        def work():
            try:
                dst = Path(mount) / EXE.name
                shutil.copyfile(EXE, dst)
                os.sync()
                res = {"done": mount, "error": ""}
            except OSError as e:
                res = {"done": "", "error": f"No se pudo copiar: {e.strerror or e}"}
            self._bg.emit("prep", res)
        threading.Thread(target=work, daemon=True).start()

    @pyqtSlot()
    def quit(self):
        QGuiApplication.quit()


def main():
    if "--watch" in sys.argv:
        from .watch import main as watch
        return watch()
    found = None
    if "--found" in sys.argv:
        i = sys.argv.index("--found")
        found = sys.argv[i + 1] if i + 1 < len(sys.argv) else None
    app = QGuiApplication(sys.argv)
    app.setApplicationName("quantum-migrate")
    app.setDesktopFileName("quantum-migrate")
    QIcon.setThemeName(os.environ.get("QUANTUM_ICON_THEME", "Papirus-Dark"))
    app.setWindowIcon(QIcon.fromTheme("quantum-migrate", QIcon.fromTheme("quantum-linux")))
    if "Inter" in QFontDatabase.families():
        app.setFont(QFont("Inter", 10))
    state = "preparar" if "--preparar" in sys.argv else os.environ.get("MIGRATE_STATE")
    m = Migrate(found, state)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("migrate", m)
    engine.rootContext().setContextProperty("store", m)      # Theme.qml lee store.colors
    engine.warnings.connect(lambda ws: [print("QML:", w.toString(), file=sys.stderr) for w in ws])
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        return 1
    shot = os.environ.get("MIGRATE_SCREENSHOT")
    if shot:
        from PyQt6 import sip
        from PyQt6.QtQuick import QQuickWindow
        win = sip.cast(engine.rootObjects()[0], QQuickWindow)
        if os.environ.get("MIGRATE_SIZE"):
            w, h = map(int, os.environ["MIGRATE_SIZE"].split("x"))
            win.setWidth(w); win.setHeight(h)
        QTimer.singleShot(int(os.environ.get("MIGRATE_WAIT", "2500")), lambda: (win.grabWindow().save(shot), app.quit()))
    return app.exec()
