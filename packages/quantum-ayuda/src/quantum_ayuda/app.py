"""Ayuda y sugerencias: reportar un problema o mandar una idea a quienes hacen Quantum (PyQt6 + QML).

Se envía al intermediario de reportes de Quantum, que lo guarda como issue en un repositorio privado de GitHub
(la dirección está en /usr/share/quantum-ayuda/endpoint).
Antes de enviar, la persona ve exactamente qué se manda y puede quitar cada parte. Los registros
se limpian de nombres de usuario, del nombre del PC, de redes Wi-Fi y de direcciones IP y MAC.
Sin internet, el envío queda guardado y se manda solo la próxima vez que se abra la app.

Uso: quantum-ayuda [--problema | --sugerencia] [--caida]   (--caida: el escritorio se acaba de caer)
Desarrollo: QUANTUM_AYUDA_DEMO=1 no envía nada (simula el envío).
"""
import datetime as dt
import json
import os
import platform
import re
import socket
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

from PyQt6.QtCore import QObject, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine

HERE = Path(__file__).resolve().parent
DEMO = bool(os.environ.get("QUANTUM_AYUDA_DEMO"))
ENDPOINT_FILE = Path(os.environ.get("QUANTUM_AYUDA_ENDPOINT_FILE", "/usr/share/quantum-ayuda/endpoint"))
HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local" / "state")) / "quantum"
QUEUE = STATE / "ayuda-pendientes"
SENT = STATE / "ayuda-enviados.json"
MAX_PER_DAY = 5
MAX_LOG = 6000             # caracteres de registros que se mandan (el formulario tiene límite)


def run(cmd, timeout=8):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


# ------------------------------------------------------------------ datos del PC
def pc_info():
    os_rel = {}
    try:
        for line in Path("/etc/os-release").read_text().splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                os_rel[k] = v.strip('"')
    except OSError:
        pass
    cpu = ""
    try:
        cpu = next((l.split(":", 1)[1].strip() for l in Path("/proc/cpuinfo").read_text().splitlines()
                    if l.startswith("model name")), "")
    except OSError:
        pass
    gpus = [re.sub(r"^.*?: ", "", l) for l in run(["lspci"]).splitlines() if re.search(r"VGA|3D|Display", l)]
    mem = ""
    try:
        kb = int(re.search(r"MemTotal:\s+(\d+)", Path("/proc/meminfo").read_text()).group(1))
        mem = f"{kb / 1048576:.1f} GB"
    except (OSError, AttributeError):
        pass
    virt = run(["systemd-detect-virt"]).strip() or "none"
    renderer = ""
    m = re.search(r"OpenGL renderer string: (.+)", run(["glxinfo", "-B"]))
    if m:
        renderer = m.group(1)
    pkgs = run(["pacman", "-Q", "quantum-shell", "quantum-desktop", "wayfire", "quickshell"]).strip().replace("\n", ", ")
    try:
        shell = json.loads((CONFIG / "quantum" / "settings.json").read_text()).get("ui", {}).get("shell", "")
    except (OSError, ValueError):
        shell = ""
    return [
        ["Sistema", f"{os_rel.get('PRETTY_NAME', 'Linux')} · kernel {platform.release()}"],
        ["Procesador", cpu or "—"],
        ["Gráfica", " / ".join(gpus) or "—"],
        ["Dibujo", renderer or "—"],
        ["Memoria", mem or "—"],
        ["Máquina virtual", "no" if virt == "none" else virt],
        ["Escritorio", (shell or "caelestial").capitalize()],
        ["Paquetes", pkgs or "—"],
    ]


# ------------------------------------------------------------------ registros
def wifi_names():
    return [n for n in run(["nmcli", "-t", "-f", "NAME", "connection", "show"]).splitlines() if n.strip()]


def sanitize(text):
    """Quita lo que identifica a la persona: usuario, nombre del PC, carpeta personal, redes Wi-Fi, IP y MAC."""
    user = os.environ.get("USER") or HOME.name
    host = socket.gethostname()
    reps = [(str(HOME), "~"), (f"/home/{user}", "~")]
    if user and len(user) > 2:
        reps.append((user, "<usuario>"))
    if host and len(host) > 2:
        reps.append((host, "<pc>"))
    for n in wifi_names():
        if len(n) > 2:
            reps.append((n, "<red>"))
    for a, b in sorted(reps, key=lambda r: -len(r[0])):
        text = text.replace(a, b)
    text = re.sub(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", "<ip>", text)
    text = re.sub(r"\b(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b", "<mac>", text)
    text = re.sub(r"\b[\w.+-]+@[\w-]+\.[\w.]+\b", "<correo>", text)
    return text


def recent_logs():
    parts = []
    crashes = sorted((HOME / ".cache" / "quickshell" / "crashes").glob("*"), key=lambda p: p.stat().st_mtime, reverse=True) \
        if (HOME / ".cache" / "quickshell" / "crashes").is_dir() else []
    if crashes:
        when = dt.datetime.fromtimestamp(crashes[0].stat().st_mtime).strftime("%d-%m %H:%M")
        parts.append(f"## Caídas del escritorio: {len(crashes)} (la última: {when})")
        # report.txt de Quickshell: versión y las primeras líneas del rastro (lo que sirve para arreglarlo)
        rep = crashes[0] / "report.txt"
        if rep.is_file():
            txt = rep.read_text(errors="ignore")
            sec = {}
            for block in re.split(r"^===== ", txt, flags=re.M)[1:]:
                name, _, body = block.partition(" =====\n")
                sec[name.strip()] = body.strip()
            parts.append(sec.get("Version Information", "")[:400])
            parts.append("\n".join(sec.get("Stacktrace", "").splitlines()[:28]))
    qs = [l for l in run(["journalctl", "--user", "-b", "-n", "400", "--no-pager", "-o", "short"]).splitlines()
          if re.search(r"WARN|ERROR|error|crash|Segmentation|TypeError|ReferenceError", l)]
    if qs:
        parts.append("## Escritorio (últimos avisos)\n" + "\n".join(qs[-40:]))
    sysl = run(["journalctl", "-b", "-p", "err", "-n", "40", "--no-pager", "-o", "short"]).strip()
    if sysl:
        parts.append("## Sistema (errores)\n" + sysl)
    text = sanitize("\n\n".join(parts) or "Sin errores recientes en los registros.")
    return text[-MAX_LOG:]


# ------------------------------------------------------------------ envío
def endpoint():
    try:
        e = ENDPOINT_FILE.read_text().strip()
        return e if e.startswith("https://") else ""          # el intermediario de reportes (o Formspree)
    except OSError:
        return ""


def post(data):
    req = urllib.request.Request(endpoint(), data=json.dumps(data).encode(),
                                 headers={"Content-Type": "application/json", "Accept": "application/json",
                                          "User-Agent": "QuantumAyuda/1.0"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return 200 <= r.status < 300


def sent_today():
    try:
        times = json.loads(SENT.read_text())
    except (OSError, ValueError):
        times = []
    now = time.time()
    return [t for t in times if now - t < 86400]


def remember_sent():
    SENT.parent.mkdir(parents=True, exist_ok=True)
    SENT.write_text(json.dumps(sent_today() + [time.time()]))


class Ayuda(QObject):
    colorsChanged = pyqtSignal()
    infoChanged = pyqtSignal()
    stateChanged = pyqtSignal()

    def __init__(self, kind, crash):
        super().__init__()
        self._kind, self._crash = kind, crash
        self._colors, self._serp = {}, False
        self._info, self._logs = [], "Leyendo los registros…"
        self._state, self._message = "", ""          # sending | sent | queued | error | limit
        self._load_colors()
        QTimer(self, interval=1500, timeout=self._load_colors).start()
        threading.Thread(target=self._collect, daemon=True).start()
        QTimer.singleShot(1500, lambda: threading.Thread(target=self._flush_queue, daemon=True).start())

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

    @pyqtProperty(str, constant=True)
    def startKind(self): return self._kind

    @pyqtProperty(bool, constant=True)
    def crash(self): return self._crash

    # ------------------------------------------------------- datos y registros
    def _collect(self):
        self._info = pc_info()
        self._logs = recent_logs()
        self.infoChanged.emit()

    @pyqtProperty("QVariant", notify=infoChanged)
    def info(self): return self._info

    @pyqtProperty(str, notify=infoChanged)
    def logs(self): return self._logs

    # ------------------------------------------------------------- envío
    @pyqtProperty(str, notify=stateChanged)
    def state(self): return self._state

    @pyqtProperty(str, notify=stateChanged)
    def message(self): return self._message

    def _set(self, state, message=""):
        self._state, self._message = state, message
        self.stateChanged.emit()

    @pyqtSlot(str, str, str, str, str, bool, bool)
    def send(self, kind, area, title, text, contact, withInfo, withLogs):
        if len(sent_today()) >= MAX_PER_DAY and not DEMO:
            self._set("limit", f"Ya enviaste {MAX_PER_DAY} mensajes hoy. Mañana puedes mandar más.")
            return
        data = {
            "_subject": f"[Quantum · {'Problema' if kind == 'problema' else 'Sugerencia'}] {title[:80]}",
            "tipo": "Problema" if kind == "problema" else "Sugerencia",
            "area": area, "titulo": title, "mensaje": text,
            "contacto": contact or "(no dejó contacto)",
            "fecha": dt.datetime.now().strftime("%Y-%m-%d %H:%M"),
        }
        if self._crash:
            data["caida"] = "Sí: el escritorio se había caído justo antes"
        if withInfo:
            data["pc"] = "\n".join(f"{k}: {v}" for k, v in self._info)
        if withLogs and kind == "problema":
            data["registros"] = self._logs
        self._set("sending")

        def work():
            if DEMO:
                time.sleep(1.4)
                self._set("sent")
                return
            if not endpoint():
                self._set("error", "Este Quantum todavía no tiene configurado a dónde enviar. Avísanos en el Discord.")
                return
            try:
                ok = post(data)
            except Exception:
                ok = None
            if ok:
                remember_sent()
                self._set("sent")
            else:
                # sin internet (o el servicio no respondió): queda guardado para después
                QUEUE.mkdir(parents=True, exist_ok=True)
                (QUEUE / f"{int(time.time() * 1000)}.json").write_text(json.dumps(data, ensure_ascii=False))
                self._set("queued")
        threading.Thread(target=work, daemon=True).start()

    def _flush_queue(self):
        if DEMO or not endpoint() or not QUEUE.is_dir():
            return
        for f in sorted(QUEUE.glob("*.json")):
            try:
                if post(json.loads(f.read_text())):
                    remember_sent()
                    f.unlink()
            except Exception:
                return          # sigue sin internet: se intenta la próxima vez

    @pyqtSlot()
    def reset(self):
        self._set("")

    @pyqtSlot(str)
    def openUrl(self, url):
        subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Ayuda y sugerencias")
    app.setDesktopFileName("quantum-ayuda")
    app.setWindowIcon(QIcon.fromTheme("quantum-ayuda", QIcon(str(HERE / "assets" / "quantum-ayuda.svg"))))
    kind = "sugerencia" if "--sugerencia" in sys.argv else "problema" if "--problema" in sys.argv or "--caida" in sys.argv else ""
    ay = Ayuda(kind, "--caida" in sys.argv)
    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    ctx.setContextProperty("ayuda", ay)
    ctx.setContextProperty("assetsDir", QUrl.fromLocalFile(str(HERE / "assets")).toString())
    engine.warnings.connect(lambda ws: [print("QML:", w.toString(), file=sys.stderr) for w in ws])
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())
