#!/usr/bin/env python3
"""Pantalla de la instalación automática: arranca el motor (como root) y muestra su avance
a pantalla completa, con la estética de Quantum. Al terminar reinicia sola.

Uso: progress.py RESPUESTAS.json      (FAKE_ENGINE=archivo.jsonl para probar la pantalla)
"""
import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

from PyQt6.QtCore import QObject, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QFont, QFontDatabase, QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

HERE = Path(__file__).resolve().parent
ENGINE = HERE / "engine.py"


class Install(QObject):
    changed = pyqtSignal()
    _line = pyqtSignal(str)

    def __init__(self, answers):
        super().__init__()
        self.answers = answers
        self._steps, self._percent, self._detail, self._state, self._error = [], 0.0, "", "running", ""
        try:
            self._name = json.loads(Path(answers).read_text()).get("user", {}).get("name", "").split(" ")[0]
        except (OSError, ValueError):
            self._name = ""
        self._line.connect(self._on_line)
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self):
        fake = os.environ.get("FAKE_ENGINE")
        if fake:
            for l in Path(fake).read_text().splitlines():
                self._line.emit(l)
                time.sleep(float(os.environ.get("FAKE_DELAY", "0.6")))
            return
        p = subprocess.Popen(["sudo", "-n", sys.executable, str(ENGINE), self.answers],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        for l in p.stdout:
            self._line.emit(l)
        if p.wait() != 0 and self._state == "running":
            self._line.emit(json.dumps({"step": "", "state": "error", "detail": "La instalación se detuvo"}))

    def _on_line(self, l):
        try:
            e = json.loads(l)
        except ValueError:
            return
        if "steps" in e:
            self._steps = [dict(s, state="waiting") for s in e["steps"]]
        elif e.get("step") == "done":
            self._state, self._percent = "done", 100.0
        else:
            st = e.get("state")
            if st == "error":
                self._state, self._error = "error", e.get("detail", "")
            for s in self._steps:
                if s["key"] == e.get("step"):
                    s["state"] = st
            if st != "error":
                self._percent = float(e.get("percent", self._percent))
                self._detail = e.get("detail", "")
        self.changed.emit()

    @pyqtProperty("QVariant", notify=changed)
    def steps(self): return self._steps

    @pyqtProperty(float, notify=changed)
    def percent(self): return self._percent

    @pyqtProperty(str, notify=changed)
    def detail(self): return self._detail

    @pyqtProperty(str, notify=changed)
    def state(self): return self._state

    @pyqtProperty(str, notify=changed)
    def error(self): return self._error

    @pyqtProperty(str, constant=True)
    def name(self): return self._name

    @pyqtSlot()
    def reboot(self):
        if os.environ.get("FAKE_ENGINE"):
            QGuiApplication.quit()
        else:
            subprocess.Popen(["systemctl", "reboot"])


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("quantum-install")
    for f in ("Inter",):
        if f in QFontDatabase.families():
            app.setFont(QFont(f, 10))
    inst = Install(sys.argv[1] if len(sys.argv) > 1 else "")
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("install", inst)
    engine.load(QUrl.fromLocalFile(str(HERE / "Progress.qml")))
    if not engine.rootObjects():
        return 1
    shot = os.environ.get("INSTALL_SCREENSHOT")
    if shot:
        from PyQt6 import sip
        from PyQt6.QtQuick import QQuickWindow
        win = sip.cast(engine.rootObjects()[0], QQuickWindow)
        QTimer.singleShot(int(os.environ.get("INSTALL_WAIT", "3000")), lambda: (win.grabWindow().save(shot), app.quit()))
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
