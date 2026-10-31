"""Archivos: el explorador de archivos de Quantum Linux (PyQt6 + QML).

Se ve como el escritorio que uses (Caelestial o Serpantium) y funciona como el
Explorador de Windows: pestañas, barra de ruta, accesos rápidos, discos y USB,
copiar/cortar/pegar con progreso, papelera, comprimir y descomprimir.

Uso: quantum-files [CARPETA ...]
Para desarrollo: QUANTUM_FILES_SCREENSHOT=captura.png guarda una captura y sale.
"""
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import threading
import time
import urllib.parse
import xml.etree.ElementTree as ET
from pathlib import Path

import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

from PyQt6.QtCore import (Qt, QFileSystemWatcher, QMimeData, QObject, QSize, QTimer, QUrl,  # noqa: E402
                          pyqtProperty, pyqtSignal, pyqtSlot)
from PyQt6.QtGui import QGuiApplication, QIcon, QImage, QImageReader  # noqa: E402
from PyQt6.QtQml import QQmlApplicationEngine  # noqa: E402
from PyQt6.QtQuick import QQuickImageProvider  # noqa: E402

HERE = Path(__file__).resolve().parent
HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local" / "state")) / "quantum"
DATA = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local" / "share"))
PREFS = CONFIG / "quantum" / "files.json"
TRASH = DATA / "Trash"
DEFAULT_PREFS = {"view": "grid", "iconSize": 1.0, "showHidden": False, "sortKey": "name", "sortAsc": True,
                 "details": True, "favorites": []}


def human_size(n):
    for unit in ("bytes", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            if unit == "bytes":
                return f"{n} bytes" if n != 1 else "1 byte"
            return f"{n:.1f} {unit}".replace(".", ",").replace(",0 ", " ")
        n /= 1024.0
    return ""


def xdg_dirs():
    """Carpetas del usuario (Escritorio, Descargas…) según xdg-user-dirs."""
    out = {"desktop": HOME / "Escritorio", "download": HOME / "Descargas", "documents": HOME / "Documentos",
           "pictures": HOME / "Imágenes", "music": HOME / "Música", "videos": HOME / "Vídeos"}
    keys = {"DESKTOP": "desktop", "DOWNLOAD": "download", "DOCUMENTS": "documents",
            "PICTURES": "pictures", "MUSIC": "music", "VIDEOS": "videos"}
    try:
        for line in (CONFIG / "user-dirs.dirs").read_text().splitlines():
            m = re.match(r'XDG_(\w+)_DIR="(.*)"', line)
            if m and m.group(1) in keys:
                out[keys[m.group(1)]] = Path(m.group(2).replace("$HOME", str(HOME)))
    except OSError:
        pass
    return out


def content_type(path, is_dir):
    if is_dir:
        return "inode/directory"
    return Gio.content_type_guess(path, None)[0] or "application/octet-stream"


def icon_names(ctype):
    try:
        return list(Gio.content_type_get_icon(ctype).get_names())
    except Exception:
        return ["text-x-generic"]


THUMB_TYPES = ("image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp", "image/svg+xml", "image/avif",
               "image/x-icon", "image/tiff")


def thumb_cache(path):
    """Miniatura ya generada por el sistema (videos, PDF…), si existe."""
    uri = Gio.File.new_for_path(path).get_uri()
    md5 = hashlib.md5(uri.encode()).hexdigest()
    for size in ("x-large", "large", "normal"):
        p = HOME / ".cache" / "thumbnails" / size / (md5 + ".png")
        if p.exists():
            return str(p)
    return ""


class IconProvider(QQuickImageProvider):
    """image://icon/<nombre[,respaldo,…]> → ícono del tema (Papirus)."""
    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Image)

    def requestImage(self, name, requested):
        s = requested if requested.width() > 0 else QSize(96, 96)
        for n in urllib.parse.unquote(name).split(","):
            icon = QIcon.fromTheme(n)
            if not icon.isNull():
                img = icon.pixmap(s).toImage()
                return img, img.size()
        img = QIcon.fromTheme("text-x-generic").pixmap(s).toImage()
        return img, img.size()


class ThumbProvider(QQuickImageProvider):
    """image://thumb/<ruta> → miniatura de una imagen, reducida al leerla (rápido)."""
    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Image)

    def requestImage(self, path, requested):
        path = urllib.parse.unquote(path)
        s = requested if requested.width() > 0 else QSize(320, 240)
        reader = QImageReader(path)
        reader.setAutoTransform(True)
        size = reader.size()
        if size.isValid() and size.width() > 0:
            # se lee ya reducida (llena el cuadro; QML recorta lo que sobra)
            reader.setScaledSize(size.scaled(s, Qt.AspectRatioMode.KeepAspectRatioByExpanding))
        img = reader.read()
        if img.isNull():
            return QImage(), QSize()
        return img, img.size()


class Files(QObject):
    colorsChanged = pyqtSignal()
    prefsChanged = pyqtSignal()
    drivesChanged = pyqtSignal()
    dirChanged = pyqtSignal(str)
    jobsChanged = pyqtSignal()
    jobFinished = pyqtSignal(str, str)          # título, error ("" si salió bien)
    searchResults = pyqtSignal(int, "QVariant", bool)
    clipboardChanged = pyqtSignal()
    toast = pyqtSignal(str)
    # desde los hilos de fondo se avisa con señales (Qt las pasa al hilo de la ventana)
    _jobEnded = pyqtSignal(str, str)
    _searchBatch = pyqtSignal(int, "QVariant", bool)

    def __init__(self):
        super().__init__()
        self._colors, self._serp = {}, False
        self._prefs = dict(DEFAULT_PREFS)
        try:
            self._prefs.update(json.loads(PREFS.read_text()))
        except (OSError, ValueError):
            pass
        self._drives = []
        self._jobs = {}
        self._job_seq = 0
        self._search_token = 0
        self._cut = False
        self.watcher = QFileSystemWatcher(self)
        self.watcher.directoryChanged.connect(lambda p: self._debounce_dir(p))
        self._dir_timer = QTimer(self, singleShot=True, interval=300, timeout=self._emit_dir)
        self._pending_dir = ""
        self._load_theme()
        QTimer(self, interval=1500, timeout=self._load_theme).start()
        self._refresh_drives()
        QTimer(self, interval=3000, timeout=self._refresh_drives).start()
        self._job_timer = QTimer(self, interval=250, timeout=self.jobsChanged.emit)
        QGuiApplication.clipboard().dataChanged.connect(self.clipboardChanged.emit)
        self._jobEnded.connect(self._job_end)
        self._searchBatch.connect(self.searchResults.emit)

    # ------------------------------------------------------------------ tema
    def _load_theme(self):
        try:
            c = json.loads((STATE / "colors.json").read_text())
        except (OSError, ValueError):
            c = {}
        try:
            serp = json.loads((CONFIG / "quantum" / "settings.json").read_text()).get("ui", {}).get("shell") == "serpantium"
        except (OSError, ValueError):
            serp = False
        if os.environ.get("QUANTUM_FILES_SHELL"):
            serp = os.environ["QUANTUM_FILES_SHELL"] == "serpantium"
        if c != self._colors or serp != self._serp:
            self._colors, self._serp = c, serp
            self.colorsChanged.emit()

    @pyqtProperty("QVariant", notify=colorsChanged)
    def colors(self):
        return self._colors

    @pyqtProperty(bool, notify=colorsChanged)
    def serp(self):
        return self._serp

    # ------------------------------------------------------------------ preferencias
    @pyqtProperty("QVariant", notify=prefsChanged)
    def prefs(self):
        return self._prefs

    @pyqtSlot(str, "QVariant")
    def setPref(self, key, value):
        if hasattr(value, "toVariant"):
            value = value.toVariant()
        self._prefs[key] = value
        try:
            PREFS.parent.mkdir(parents=True, exist_ok=True)
            PREFS.write_text(json.dumps(self._prefs, indent=2, ensure_ascii=False))
        except OSError:
            pass
        self.prefsChanged.emit()

    @pyqtSlot(str)
    def toggleFavorite(self, path):
        fav = list(self._prefs.get("favorites", []))
        if path in fav:
            fav.remove(path)
            self.toast.emit("Quitado de Favoritos")
        else:
            fav.append(path)
            self.toast.emit("Agregado a Favoritos")
        self.setPref("favorites", fav)

    # ------------------------------------------------------------------ lugares
    @pyqtProperty(str, constant=True)
    def home(self):
        return str(HOME)

    @pyqtProperty(str, constant=True)
    def userName(self):
        return HOME.name

    @pyqtProperty("QVariant", constant=True)
    def places(self):
        d = xdg_dirs()
        names = [("desktop", "Escritorio"), ("download", "Descargas"), ("documents", "Documentos"),
                 ("pictures", "Imágenes"), ("music", "Música"), ("videos", "Videos")]
        out = []
        for key, name in names:
            p = d[key]
            if p.is_dir():
                try:
                    count = sum(1 for e in os.scandir(p) if not e.name.startswith("."))
                except OSError:
                    count = 0
                out.append({"key": key, "name": name, "path": str(p), "count": count})
        return out

    @pyqtSlot(result="QVariant")
    def recent(self):
        """Archivos recientes (los anotan las apps en recently-used.xbel)."""
        out = []
        try:
            root = ET.parse(DATA / "recently-used.xbel").getroot()
        except (OSError, ET.ParseError):
            return out
        items = []
        for b in root.iter("bookmark"):
            href = b.get("href", "")
            if not href.startswith("file://"):
                continue
            path = urllib.parse.unquote(href[7:])
            items.append((b.get("modified") or b.get("visited") or "", path))
        items.sort(reverse=True)
        seen = set()
        for _, path in items:
            if path in seen or not os.path.isfile(path):
                continue
            seen.add(path)
            out.append(self._entry(path))
            if len(out) >= 12:
                break
        return out

    # ------------------------------------------------------------------ discos
    def _refresh_drives(self):
        try:
            raw = subprocess.run(["lsblk", "-J", "-b", "-o", "NAME,PATH,LABEL,SIZE,FSTYPE,MOUNTPOINTS,RM,HOTPLUG,TYPE,FSAVAIL,FSSIZE,PARTTYPENAME"],
                                 capture_output=True, text=True, timeout=5).stdout
            devs = json.loads(raw).get("blockdevices", [])
        except (OSError, ValueError, subprocess.SubprocessError):
            return
        out = []

        def walk(d, removable):
            removable = removable or d.get("rm") or d.get("hotplug")
            for ch in d.get("children") or []:
                walk(ch, removable)
            fs, typ = d.get("fstype"), d.get("type")
            # btrfs monta varios subvolúmenes de la misma partición: vale el de «/» (o el primero)
            mps = [m for m in (d.get("mountpoints") or []) if m]
            mp = "/" if "/" in mps else (mps[0] if mps else None)
            if typ not in ("part", "disk", "crypt", "lvm") or not fs or fs in ("swap", "crypto_LUKS", "LVM2_member"):
                return
            if mp in ("/boot", "/boot/efi", "/efi") or (mp or "").startswith(("/run/archiso", "/var", "/home/")) and mp != str(HOME):
                return
            if fs == "vfat" and not removable and not d.get("label"):
                return                               # partición EFI
            if not removable and not mp and int(d.get("size") or 0) < 2 * 1024 ** 3:
                return                               # particiones chicas de arranque o recuperación
            if mp and (mp.startswith("/.") or mp in ("/home", "/srv", "/root", "/opt", "/tmp")):
                return                               # subvolúmenes de btrfs: son parte de Quantum
            label = d.get("label") or ""
            part = (d.get("parttypename") or "").lower()
            if mp == "/":
                name, icon, kind = "Quantum", "drive-harddisk-system", "system"
            elif fs == "ntfs" and not removable:
                if "recovery" in part or "recuper" in label.lower():
                    return                           # partición de recuperación de Windows
                name, icon, kind = (label or "Windows"), "drive-harddisk", "windows"
            elif removable:
                name, icon, kind = (label or "USB " + human_size(int(d.get("size") or 0))), "drive-removable-media-usb-pendrive", "usb"
            else:
                name, icon, kind = (label or "Disco " + human_size(int(d.get("size") or 0))), "drive-harddisk", "disk"
            size = int(d.get("fssize") or d.get("size") or 0)
            avail = int(d.get("fsavail") or 0)
            out.append({"dev": d.get("path"), "name": name, "icon": icon, "kind": kind, "mount": mp or "",
                        "size": size, "free": avail, "used": (1 - avail / size) if size and mp else 0,
                        "text": (f"{human_size(avail)} libres de {human_size(size)}" if mp and size else "Sin abrir · " + human_size(int(d.get("size") or 0))),
                        "removable": bool(removable)})
        for d in devs:
            walk(d, False)
        order = {"system": 0, "windows": 1, "disk": 2, "usb": 3}
        out.sort(key=lambda x: (order.get(x["kind"], 9), x["name"].lower()))
        # quita duplicados de / (btrfs con subvolúmenes aparece varias veces)
        seen, uniq = set(), []
        for d in out:
            if d["dev"] in seen:
                continue
            seen.add(d["dev"])
            uniq.append(d)
        if uniq != self._drives:
            self._drives = uniq
            self.drivesChanged.emit()

    @pyqtProperty("QVariant", notify=drivesChanged)
    def drives(self):
        return self._drives

    @pyqtSlot(str, result=str)
    def mount(self, dev):
        """Abre (monta) un disco o USB y devuelve dónde quedó."""
        r = subprocess.run(["udisksctl", "mount", "-b", dev, "--no-user-interaction"], capture_output=True, text=True)
        self._refresh_drives()
        m = re.search(r" at (.+?)\.?$", r.stdout.strip())
        if r.returncode != 0:
            err = r.stderr.strip()
            if "NotAuthorized" in err:
                r = subprocess.run(["udisksctl", "mount", "-b", dev], capture_output=True, text=True)
                m = re.search(r" at (.+?)\.?$", r.stdout.strip())
                self._refresh_drives()
            if r.returncode != 0:
                self.toast.emit("No se pudo abrir el disco" + (" (¿Windows está en hibernación? Apágalo del todo)" if "hibernat" in err.lower() or "unclean" in err.lower() else ""))
                return ""
        return m.group(1) if m else ""

    @pyqtSlot(str)
    def eject(self, dev):
        def run():
            r = subprocess.run(["udisksctl", "unmount", "-b", dev], capture_output=True, text=True)
            if r.returncode == 0:
                subprocess.run(["udisksctl", "power-off", "-b", re.sub(r"p?\d+$", "", dev)], capture_output=True)
                self.toast.emit("Ya puedes sacar el dispositivo")
            else:
                self.toast.emit("No se pudo expulsar: hay archivos abiertos o copiándose")
        threading.Thread(target=run, daemon=True).start()

    # ------------------------------------------------------------------ carpetas
    def _entry(self, path, st=None):
        try:
            st = st or os.stat(path)
        except OSError:
            st = None
        is_dir = bool(st and stat.S_ISDIR(st.st_mode))
        ctype = content_type(path, is_dir)
        name = os.path.basename(path) or path
        icons = icon_names(ctype) if not is_dir else ["folder"]
        thumb = ""
        if not is_dir:
            if ctype in THUMB_TYPES:
                thumb = "image://thumb/" + urllib.parse.quote(path)
            else:
                c = thumb_cache(path)
                thumb = "file://" + c if c else ""
        return {"name": name, "path": path, "dir": is_dir, "size": st.st_size if st and not is_dir else 0,
                "mtime": st.st_mtime if st else 0, "type": ctype, "icon": ",".join(icons + ["text-x-generic"]),
                "thumb": thumb, "hidden": name.startswith("."),
                "desc": "Carpeta" if is_dir else (Gio.content_type_get_description(ctype) or "Archivo").capitalize()}

    @pyqtSlot(str, result="QVariant")
    def list(self, path):
        """Contenido de una carpeta: {ok, error, items}. Carpetas primero."""
        items = []
        try:
            with os.scandir(path) as it:
                for e in it:
                    try:
                        st = e.stat()
                    except OSError:
                        try:
                            st = e.stat(follow_symlinks=False)
                        except OSError:
                            continue
                    items.append(self._entry(e.path, st))
        except PermissionError:
            return {"ok": False, "error": "No tienes permiso para ver esta carpeta.", "items": []}
        except FileNotFoundError:
            return {"ok": False, "error": "Esta carpeta ya no existe.", "items": []}
        except OSError as e:
            return {"ok": False, "error": f"No se pudo abrir: {e.strerror}", "items": []}
        old = self.watcher.directories()
        if old:
            self.watcher.removePaths(old)
        self.watcher.addPath(path)
        return {"ok": True, "error": "", "items": items}

    def _debounce_dir(self, p):
        self._pending_dir = p
        self._dir_timer.start()

    def _emit_dir(self):
        self.dirChanged.emit(self._pending_dir)

    @pyqtSlot(str, result=bool)
    def isDir(self, path):
        return os.path.isdir(os.path.expanduser(path))

    @pyqtSlot(str, result=str)
    def expand(self, path):
        p = os.path.expanduser(path.strip())
        return os.path.normpath(p) if p else ""

    @pyqtSlot(str, result="QVariant")
    def crumbs(self, path):
        """Partes de la ruta para la barra: dentro de tu carpeta personal parte de tu nombre."""
        p = Path(path)
        try:
            rel = p.relative_to(HOME)
            parts = [{"name": HOME.name, "path": str(HOME)}]
            cur = HOME
        except ValueError:
            rel = p.relative_to("/") if p.is_absolute() else p
            parts = [{"name": "Quantum", "path": "/"}]
            cur = Path("/")
        for part in rel.parts:
            cur = cur / part
            parts.append({"name": part, "path": str(cur)})
        return parts

    @pyqtSlot(str, result=str)
    def parentOf(self, path):
        return str(Path(path).parent)

    @pyqtSlot(str, result="QVariant")
    def info(self, path):
        e = self._entry(path)
        e["sizeText"] = human_size(e["size"]) if not e["dir"] else ""
        e["date"] = self.dateText(e["mtime"])
        return e

    @pyqtSlot(float, result=str)
    def dateText(self, mtime):
        if not mtime:
            return ""
        t = time.localtime(mtime)
        now = time.localtime()
        hm = time.strftime("%H:%M", t)
        days = (time.mktime(now[:3] + (0, 0, 0, 0, 0, -1)) - time.mktime(t[:3] + (0, 0, 0, 0, 0, -1))) / 86400
        if days < 1:
            return "Hoy, " + hm
        if days < 2:
            return "Ayer, " + hm
        months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sept", "oct", "nov", "dic"]
        if t.tm_year == now.tm_year:
            return f"{t.tm_mday} {months[t.tm_mon - 1]}, {hm}"
        return f"{t.tm_mday} {months[t.tm_mon - 1]} {t.tm_year}"

    @pyqtSlot(float, result=str)
    def sizeText(self, n):
        return human_size(int(n))

    @pyqtSlot("QVariant", result=str)
    def totalSize(self, paths):
        paths = paths.toVariant() if hasattr(paths, "toVariant") else paths
        total = 0
        for p in paths or []:
            try:
                if os.path.isfile(p):
                    total += os.path.getsize(p)
            except OSError:
                pass
        return human_size(total)

    # ------------------------------------------------------------------ abrir
    @pyqtSlot("QVariant")
    def open(self, paths):
        paths = paths.toVariant() if hasattr(paths, "toVariant") else paths
        for p in paths or []:
            try:
                Gio.AppInfo.launch_default_for_uri(Gio.File.new_for_path(p).get_uri(), None)
            except GLib.Error:
                subprocess.Popen(["xdg-open", p], start_new_session=True)

    @pyqtSlot(str, result="QVariant")
    def appsFor(self, path):
        ctype = content_type(path, os.path.isdir(path))
        out, seen = [], set()
        default = Gio.AppInfo.get_default_for_type(ctype, False)
        apps = ([default] if default else []) + list(Gio.AppInfo.get_all_for_type(ctype))
        for a in apps:
            if not a or a.get_id() in seen or not a.should_show():
                continue
            seen.add(a.get_id())
            icon = a.get_icon()
            names = icon.get_names() if icon and hasattr(icon, "get_names") else ["application-x-executable"]
            out.append({"id": a.get_id(), "name": a.get_name(), "icon": ",".join(names + ["application-x-executable"]),
                        "default": default is not None and a.get_id() == default.get_id()})
        return out[:12]

    @pyqtSlot(str, "QVariant", bool)
    def openWith(self, app_id, paths, make_default):
        paths = paths.toVariant() if hasattr(paths, "toVariant") else paths
        try:
            app = Gio.DesktopAppInfo.new(app_id)
            app.launch([Gio.File.new_for_path(p) for p in paths], None)
            if make_default and paths:
                app.set_as_default_for_type(content_type(paths[0], os.path.isdir(paths[0])))
        except (GLib.Error, TypeError) as e:
            self.toast.emit(f"No se pudo abrir: {e}")

    @pyqtSlot(str)
    def terminal(self, folder):
        subprocess.Popen(["kitty", "--directory", folder], start_new_session=True)

    @pyqtSlot(str)
    def setWallpaper(self, path):
        subprocess.Popen(["quantum-theme", "wallpaper", path], start_new_session=True)
        self.toast.emit("Fondo de pantalla cambiado")

    # ------------------------------------------------------------------ editar
    @pyqtSlot(str, str, result=str)
    def rename(self, path, new_name):
        new_name = new_name.strip()
        if not new_name or "/" in new_name or new_name in (".", ".."):
            return "Ese nombre no sirve."
        dest = os.path.join(os.path.dirname(path), new_name)
        if os.path.exists(dest) and os.path.realpath(dest) != os.path.realpath(path):
            return "Ya hay algo con ese nombre."
        try:
            os.rename(path, dest)
        except OSError as e:
            return f"No se pudo renombrar: {e.strerror}"
        return ""

    def _free_name(self, folder, name):
        base, ext = os.path.splitext(name)
        if name.startswith(".") and base == "":
            base, ext = name, ""
        cand, n = os.path.join(folder, name), 2
        while os.path.lexists(cand):
            cand = os.path.join(folder, f"{base} ({n}){ext}")
            n += 1
        return cand

    @pyqtSlot(str, str, result=str)
    def newFolder(self, folder, name):
        p = self._free_name(folder, name or "Nueva carpeta")
        try:
            os.mkdir(p)
        except OSError as e:
            self.toast.emit(f"No se pudo crear la carpeta: {e.strerror}")
            return ""
        return p

    @pyqtSlot(str, str, result=str)
    def newFile(self, folder, name):
        p = self._free_name(folder, name or "Documento nuevo.txt")
        try:
            open(p, "x").close()
        except OSError as e:
            self.toast.emit(f"No se pudo crear el archivo: {e.strerror}")
            return ""
        return p

    @pyqtSlot("QVariant")
    def trash(self, paths):
        paths = paths.toVariant() if hasattr(paths, "toVariant") else paths
        bad = 0
        for p in paths or []:
            try:
                Gio.File.new_for_path(p).trash(None)
            except GLib.Error:
                bad += 1
        n = len(paths or []) - bad
        if n:
            self.toast.emit("Enviado a la Papelera" if n == 1 else f"{n} elementos enviados a la Papelera")
        if bad:
            self.toast.emit("Algunos archivos no se pueden mandar a la Papelera (¿USB o sin permiso?). Usa Mayús + Supr para borrarlos.")

    @pyqtSlot("QVariant")
    def deleteForever(self, paths):
        paths = paths.toVariant() if hasattr(paths, "toVariant") else paths

        def work(job):
            for i, p in enumerate(paths):
                job["label"] = os.path.basename(p)
                if os.path.isdir(p) and not os.path.islink(p):
                    shutil.rmtree(p)
                else:
                    os.remove(p)
                job["done"] = i + 1
        self._start_job("Eliminando", len(paths), work, unit="items")

    # ------------------------------------------------------------------ papelera
    @pyqtSlot(result="QVariant")
    def trashList(self):
        out = []
        files = TRASH / "files"
        try:
            for e in os.scandir(files):
                item = self._entry(e.path)
                try:
                    txt = (TRASH / "info" / (e.name + ".trashinfo")).read_text()
                    m = re.search(r"^Path=(.*)$", txt, re.M)
                    item["origin"] = urllib.parse.unquote(m.group(1)) if m else ""
                except OSError:
                    item["origin"] = ""
                out.append(item)
        except OSError:
            pass
        return out

    @pyqtSlot("QVariant")
    def restore(self, paths):
        paths = paths.toVariant() if hasattr(paths, "toVariant") else paths
        for p in paths or []:
            name = os.path.basename(p)
            info = TRASH / "info" / (name + ".trashinfo")
            try:
                m = re.search(r"^Path=(.*)$", info.read_text(), re.M)
                dest = urllib.parse.unquote(m.group(1))
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                shutil.move(p, self._free_name(os.path.dirname(dest), os.path.basename(dest)))
                info.unlink(missing_ok=True)
            except (OSError, AttributeError):
                self.toast.emit("No se pudo restaurar " + name)
        self.toast.emit("Restaurado")

    @pyqtSlot()
    def emptyTrash(self):
        def work(job):
            items = list((TRASH / "files").iterdir()) if (TRASH / "files").exists() else []
            job["total"] = max(1, len(items))
            for i, p in enumerate(items):
                if p.is_dir() and not p.is_symlink():
                    shutil.rmtree(p, ignore_errors=True)
                else:
                    p.unlink(missing_ok=True)
                (TRASH / "info" / (p.name + ".trashinfo")).unlink(missing_ok=True)
                job["done"] = i + 1
        self._start_job("Vaciando la Papelera", 1, work, unit="items")

    # ------------------------------------------------------------------ portapapeles
    @pyqtSlot("QVariant", bool)
    def setClipboard(self, paths, cut):
        paths = paths.toVariant() if hasattr(paths, "toVariant") else paths
        md = QMimeData()
        urls = [QUrl.fromLocalFile(p) for p in paths]
        md.setUrls(urls)
        # el formato que entienden Nautilus/Dolphin y las apps de GTK para «cortar»
        gnome = ("cut" if cut else "copy") + "\n" + "\n".join(u.toString() for u in urls)
        md.setData("x-special/gnome-copied-files", gnome.encode())
        md.setText("\n".join(paths))
        QGuiApplication.clipboard().setMimeData(md)
        self._cut = cut
        self.toast.emit(("Cortado: " if cut else "Copiado: ") + (os.path.basename(paths[0]) if len(paths) == 1 else f"{len(paths)} elementos"))

    @pyqtProperty(bool, notify=clipboardChanged)
    def canPaste(self):
        md = QGuiApplication.clipboard().mimeData()
        return bool(md and md.hasUrls() and any(u.isLocalFile() for u in md.urls()))

    @pyqtSlot(str)
    def paste(self, dest):
        md = QGuiApplication.clipboard().mimeData()
        if not md or not md.hasUrls():
            return
        paths = [u.toLocalFile() for u in md.urls() if u.isLocalFile()]
        cut = self._cut
        if md.hasFormat("x-special/gnome-copied-files"):
            cut = bytes(md.data("x-special/gnome-copied-files")).decode(errors="ignore").startswith("cut")
        self.transfer(paths, dest, cut)
        if cut:
            QGuiApplication.clipboard().clear()

    # ------------------------------------------------------------------ copiar / mover
    @pyqtSlot("QVariant", str, bool)
    def transfer(self, paths, dest, move):
        paths = paths.toVariant() if hasattr(paths, "toVariant") else paths
        paths = [p for p in paths if p and os.path.abspath(p) != os.path.abspath(dest)
                 and not os.path.abspath(dest).startswith(os.path.abspath(p) + os.sep)]
        if not paths:
            return
        total = 0
        for p in paths:
            if os.path.isdir(p) and not os.path.islink(p):
                for r, _, fs in os.walk(p):
                    for f in fs:
                        try:
                            total += os.lstat(os.path.join(r, f)).st_size
                        except OSError:
                            pass
            else:
                try:
                    total += os.lstat(p).st_size
                except OSError:
                    pass
        where = "aquí" if not dest else os.path.basename(dest) or dest
        title = ("Moviendo " if move else "Copiando ") + (f"«{os.path.basename(paths[0])}»" if len(paths) == 1 else f"{len(paths)} elementos") + f" a {where}"

        def copy_file(src, dst, job):
            with open(src, "rb") as fi, open(dst, "wb") as fo:
                while True:
                    if job["cancel"]:
                        raise InterruptedError
                    while job["paused"] and not job["cancel"]:
                        time.sleep(0.2)
                    buf = fi.read(4 * 1024 * 1024)
                    if not buf:
                        break
                    fo.write(buf)
                    job["done"] += len(buf)
            shutil.copystat(src, dst, follow_symlinks=False)

        def copy_any(src, dst, job):
            job["label"] = os.path.basename(src)
            if os.path.islink(src):
                os.symlink(os.readlink(src), dst)
            elif os.path.isdir(src):
                os.makedirs(dst, exist_ok=True)
                for e in os.scandir(src):
                    copy_any(e.path, os.path.join(dst, e.name), job)
                shutil.copystat(src, dst, follow_symlinks=False)
            else:
                copy_file(src, dst, job)

        def work(job):
            for p in paths:
                target = self._free_name(dest, os.path.basename(p)) if os.path.dirname(os.path.abspath(p)) != os.path.abspath(dest) or not move else None
                if target is None:
                    continue
                if move:
                    try:
                        os.rename(p, target)            # mismo disco: instantáneo
                        continue
                    except OSError:
                        pass
                    copy_any(p, target, job)
                    if os.path.isdir(p) and not os.path.islink(p):
                        shutil.rmtree(p)
                    else:
                        os.remove(p)
                else:
                    copy_any(p, target, job)
            job["done"] = job["total"]
        self._start_job(title, max(1, total), work, cancellable=True)

    @pyqtSlot("QVariant", str)
    def compress(self, paths, folder):
        paths = paths.toVariant() if hasattr(paths, "toVariant") else paths
        name = (os.path.splitext(os.path.basename(paths[0]))[0] if len(paths) == 1 else "Archivos") + ".zip"
        out = self._free_name(folder, name)

        def work(job):
            r = subprocess.run(["bsdtar", "-a", "-cf", out, "-C", folder] + [os.path.relpath(p, folder) for p in paths],
                               capture_output=True, text=True)
            if r.returncode != 0:
                raise RuntimeError(r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "error al comprimir")
            job["done"] = 1
        self._start_job(f"Comprimiendo en «{os.path.basename(out)}»", 1, work, unit="items")

    @pyqtSlot(str)
    def extract(self, path):
        folder = os.path.dirname(path)
        base = os.path.basename(path)
        for ext in (".tar.gz", ".tar.xz", ".tar.zst", ".tar.bz2", ".tgz", ".zip", ".7z", ".rar", ".tar", ".iso"):
            if base.lower().endswith(ext):
                base = base[: -len(ext)]
                break
        out = self._free_name(folder, base)

        def work(job):
            os.makedirs(out)
            r = subprocess.run(["bsdtar", "-xf", path, "-C", out], capture_output=True, text=True)
            if r.returncode != 0:
                raise RuntimeError("No se pudo descomprimir (¿archivo dañado o con contraseña?)")
            job["done"] = 1
        self._start_job(f"Descomprimiendo «{os.path.basename(path)}»", 1, work, unit="items")

    @pyqtSlot(str, result=bool)
    def isArchive(self, path):
        return bool(re.search(r"\.(zip|7z|rar|tar|tgz|tar\.(gz|xz|zst|bz2))$", path, re.I))

    # ------------------------------------------------------------------ tareas en segundo plano
    def _start_job(self, title, total, work, cancellable=False, unit="bytes"):
        self._job_seq += 1
        jid = str(self._job_seq)
        job = {"id": jid, "title": title, "total": total, "done": 0, "label": "", "cancel": False, "paused": False,
               "cancellable": cancellable, "unit": unit, "start": time.time()}
        self._jobs[jid] = job

        def run():
            err = ""
            try:
                work(job)
            except InterruptedError:
                err = "Cancelado"
            except PermissionError:
                err = "No tienes permiso para escribir ahí."
            except OSError as e:
                err = "No hay espacio suficiente." if e.errno == 28 else f"Error: {e.strerror or e}"
            except Exception as e:  # nunca dejar la ventana colgada
                err = str(e)
            self._jobs.pop(jid, None)
            self._jobEnded.emit(title, err)
        threading.Thread(target=run, daemon=True).start()
        self._job_timer.start()
        self.jobsChanged.emit()

    def _job_end(self, title, err):
        if not self._jobs:
            self._job_timer.stop()
        self.jobsChanged.emit()
        self.jobFinished.emit(title, err)

    @pyqtProperty("QVariant", notify=jobsChanged)
    def jobs(self):
        out = []
        for j in self._jobs.values():
            frac = min(1.0, j["done"] / j["total"]) if j["total"] else 0
            elapsed = time.time() - j["start"]
            left = ""
            if j["unit"] == "bytes" and frac > 0.02 and elapsed > 1:
                secs = elapsed / frac - elapsed
                left = "quedan unos %d segundos" % max(1, secs) if secs < 90 else "quedan unos %d minutos" % (secs / 60 + 0.5)
            out.append({"id": j["id"], "title": j["title"], "frac": frac, "label": j["label"], "left": left,
                        "paused": j["paused"], "cancellable": j["cancellable"],
                        "detail": f"{human_size(j['done'])} de {human_size(j['total'])}" if j["unit"] == "bytes" else ""})
        return out

    @pyqtSlot(str)
    def cancelJob(self, jid):
        if jid in self._jobs:
            self._jobs[jid]["cancel"] = True

    @pyqtSlot(str)
    def pauseJob(self, jid):
        if jid in self._jobs:
            self._jobs[jid]["paused"] = not self._jobs[jid]["paused"]
            self.jobsChanged.emit()

    # ------------------------------------------------------------------ búsqueda
    @pyqtSlot(str, str, result=int)
    def search(self, folder, query):
        self._search_token += 1
        token = self._search_token
        q = query.strip().lower()
        hidden = bool(self._prefs.get("showHidden"))

        def run():
            batch, count = [], 0
            last = time.time()
            for root, dirs, files in os.walk(folder):
                if token != self._search_token:
                    return
                if not hidden:
                    dirs[:] = [d for d in dirs if not d.startswith(".")]
                for n in dirs + files:
                    if q in n.lower() and (hidden or not n.startswith(".")):
                        batch.append(self._entry(os.path.join(root, n)))
                        count += 1
                if batch and time.time() - last > 0.3:
                    b, batch, last = batch, [], time.time()
                    self._searchBatch.emit(token, b, False)
                if count >= 1000:
                    break
            self._searchBatch.emit(token, batch, True)
        threading.Thread(target=run, daemon=True).start()
        return token

    # ------------------------------------------------------------------ arrastrar fuera
    @pyqtSlot("QVariant", result="QVariant")
    def uriList(self, paths):
        paths = paths.toVariant() if hasattr(paths, "toVariant") else paths
        return [QUrl.fromLocalFile(p).toString() for p in paths]

    @pyqtSlot("QVariant", result="QVariant")
    def localPaths(self, urls):
        urls = urls.toVariant() if hasattr(urls, "toVariant") else urls
        out = []
        for u in urls or []:
            u = u.toString() if hasattr(u, "toString") else str(u)
            if u.startswith("file://"):
                out.append(urllib.parse.unquote(u[7:]))
        return out


def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Archivos")
    app.setDesktopFileName("quantum-files")
    app.setWindowIcon(QIcon.fromTheme("quantum-files", QIcon(str(HERE / "assets" / "quantum-files.svg"))))
    if not QIcon.themeName() or QIcon.themeName() == "hicolor":
        QIcon.setThemeName("Papirus-Dark")
    fm = Files()
    engine = QQmlApplicationEngine()
    engine.addImageProvider("icon", IconProvider())
    engine.addImageProvider("thumb", ThumbProvider())
    # carpetas (o file://… como las pasan otras apps); si es un archivo, se abre su carpeta
    start = []
    for a in sys.argv[1:]:
        if a.startswith("-"):
            continue
        if a.startswith("file://"):
            a = urllib.parse.unquote(urllib.parse.urlparse(a).path)
        a = os.path.abspath(os.path.expanduser(a))
        if os.path.isfile(a):
            a = os.path.dirname(a)
        if os.path.isdir(a):
            start.append(a)
    ctx = engine.rootContext()
    ctx.setContextProperty("fm", fm)
    ctx.setContextProperty("startPaths", start)
    ctx.setContextProperty("shotPath", os.environ.get("QUANTUM_FILES_SCREENSHOT", ""))
    ctx.setContextProperty("demoAction", os.environ.get("QUANTUM_FILES_DEMO", ""))
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())
