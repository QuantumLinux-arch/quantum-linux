"""Pasa a Quantum lo que «Pasar a Quantum.exe» dejó en el pendrive (ver FORMATO.md).

Cada paso es independiente: si uno falla, los demás siguen y se informa al final.
Nunca se pisa nada: si un archivo ya existe y es distinto, el de Windows se guarda como
«nombre (Windows).ext».
"""
import configparser
import html
import json
import os
import re
import shutil
import sqlite3
import subprocess
import time
from pathlib import Path

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
DATA = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local" / "share"))
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local" / "state")) / "quantum"
SETTINGS = CONFIG / "quantum" / "settings.json"
DONE = STATE / "migrate-done"
FOLDER = "Quantum - Mis cosas de Windows"

# ----------------------------------------------------------- tablas de equivalencias

# Zonas horarias de Windows → IANA (las de Latinoamérica, España y las más comunes)
TIMEZONES = {
    "Pacific SA Standard Time": "America/Santiago", "Magallanes Standard Time": "America/Punta_Arenas",
    "Easter Island Standard Time": "Pacific/Easter", "Argentina Standard Time": "America/Argentina/Buenos_Aires",
    "SA Pacific Standard Time": "America/Bogota", "SA Western Standard Time": "America/La_Paz",
    "SA Eastern Standard Time": "America/Cayenne", "E. South America Standard Time": "America/Sao_Paulo",
    "Central Standard Time (Mexico)": "America/Mexico_City", "Mountain Standard Time (Mexico)": "America/Mazatlan",
    "Pacific Standard Time (Mexico)": "America/Tijuana", "Eastern Standard Time (Mexico)": "America/Cancun",
    "Central America Standard Time": "America/Guatemala", "Venezuela Standard Time": "America/Caracas",
    "Paraguay Standard Time": "America/Asuncion", "Montevideo Standard Time": "America/Montevideo",
    "Cuba Standard Time": "America/Havana", "Haiti Standard Time": "America/Port-au-Prince",
    "Atlantic Standard Time": "America/Halifax", "Eastern Standard Time": "America/New_York",
    "Central Standard Time": "America/Chicago", "Mountain Standard Time": "America/Denver",
    "US Mountain Standard Time": "America/Phoenix", "Pacific Standard Time": "America/Los_Angeles",
    "Romance Standard Time": "Europe/Madrid", "Canary Islands Standard Time": "Atlantic/Canary",
    "GMT Standard Time": "Europe/London", "W. Europe Standard Time": "Europe/Berlin",
    "Central Europe Standard Time": "Europe/Budapest", "UTC": "UTC", "Greenwich Standard Time": "Atlantic/Reykjavik",
}

# Distribuciones de teclado de Windows (KLID) → (layout, variante) de xkb
KEYBOARDS = {
    "0000080a": ("latam", ""), "0000040a": ("es", ""), "00000c0a": ("es", ""), "00000409": ("us", ""),
    "00020409": ("us", "intl"), "00010409": ("us", "dvorak"), "00000809": ("gb", ""), "00000416": ("br", ""),
    "00010416": ("br", ""), "00000816": ("pt", ""), "0000040c": ("fr", ""), "00000407": ("de", ""),
    "00000410": ("it", ""), "0000080c": ("be", ""), "00000807": ("ch", ""), "0000100c": ("ch", "fr"),
    "00011009": ("ca", "multix"), "00001009": ("ca", "fr"), "00000403": ("es", "cat"),
}

# Programas de Windows → lo que se instala en Quantum. (patrón, nombre, id de Flathub o None si ya viene, nota)
APPS = [
    (r"google chrome", "Google Chrome", "com.google.Chrome", "El mismo de siempre"),
    (r"microsoft edge(?! webview)", "Microsoft Edge", "com.microsoft.Edge", "El mismo de siempre"),
    (r"\bbrave\b", "Brave", "com.brave.Browser", "El mismo de siempre"),
    (r"\bopera\b(?! gx)", "Opera", "com.opera.Opera", "El mismo de siempre"),
    (r"opera gx", "Opera", "com.opera.Opera", "Opera GX no existe para Linux: Opera es lo más cercano"),
    (r"vivaldi", "Vivaldi", "com.vivaldi.Vivaldi", "El mismo de siempre"),
    (r"firefox", "Firefox", None, "Ya viene en Quantum"),
    (r"\bsteam\b", "Steam", None, "Ya viene en Quantum"),
    (r"discord", "Discord", "com.discordapp.Discord", "El mismo de siempre"),
    (r"spotify", "Spotify", "com.spotify.Client", "El mismo de siempre"),
    (r"telegram", "Telegram", "org.telegram.desktop", "El mismo de siempre"),
    (r"whatsapp", "WhatsApp", "com.github.eneshecan.WhatsAppForLinux", "Versión para Linux hecha por la comunidad"),
    (r"zoom", "Zoom", "us.zoom.Zoom", "El mismo de siempre"),
    (r"obs studio", "OBS Studio", "com.obsproject.Studio", "El mismo de siempre"),
    (r"\bvlc\b", "VLC", "org.videolan.VLC", "El mismo de siempre"),
    (r"epic games", "Heroic (Epic Games)", "com.heroicgameslauncher.hgl", "Tus juegos de Epic, en una app para Linux"),
    (r"gog galaxy", "Heroic (GOG)", "com.heroicgameslauncher.hgl", "Tus juegos de GOG, en una app para Linux"),
    (r"battle\.net|ea app|origin|ubisoft connect|uplay", "Lutris", "net.lutris.Lutris", "Para Battle.net, EA y Ubisoft"),
    (r"minecraft", "Minecraft (Prism Launcher)", "org.prismlauncher.PrismLauncher", "Con tu misma cuenta de Minecraft"),
    (r"roblox", "Roblox (Sober)", "org.vinegarhq.Sober", "Con tu misma cuenta de Roblox"),
    (r"microsoft office|microsoft 365|word|excel|powerpoint", "LibreOffice", "org.libreoffice.LibreOffice", "Abre y guarda archivos de Office"),
    (r"adobe photoshop|paint\.net|photoscape", "GIMP", "org.gimp.GIMP", "Editor de fotos"),
    (r"clip studio|krita", "Krita", "org.kde.krita", "Para dibujar y pintar"),
    (r"illustrator|coreldraw|inkscape", "Inkscape", "org.inkscape.Inkscape", "Diseño vectorial"),
    (r"premiere|vegas|capcut|filmora|davinci", "Kdenlive", "org.kde.kdenlive", "Editor de video"),
    (r"audacity", "Audacity", "org.audacityteam.Audacity", "El mismo de siempre"),
    (r"blender", "Blender", "org.blender.Blender", "El mismo de siempre"),
    (r"gimp", "GIMP", "org.gimp.GIMP", "El mismo de siempre"),
    (r"visual studio code|vs ?code", "Visual Studio Code", "com.visualstudio.code", "El mismo de siempre"),
    (r"notepad\+\+", "Kate", "org.kde.kate", "Editor de texto para programar"),
    (r"thunderbird|outlook", "Thunderbird", "org.mozilla.Thunderbird", "Correo"),
    (r"qbittorrent|utorrent|bittorrent", "qBittorrent", "org.qbittorrent.qBittorrent", "Descargas por torrent"),
    (r"handbrake", "HandBrake", "fr.handbrake.ghb", "El mismo de siempre"),
    (r"anydesk", "AnyDesk", "com.anydesk.Anydesk", "El mismo de siempre"),
    (r"teamviewer", "TeamViewer", "com.teamviewer.TeamViewer", "El mismo de siempre"),
    (r"obsidian", "Obsidian", "md.obsidian.Obsidian", "El mismo de siempre"),
    (r"signal", "Signal", "org.signal.Signal", "El mismo de siempre"),
    (r"slack", "Slack", "com.slack.Slack", "El mismo de siempre"),
    (r"postman", "Postman", "com.getpostman.Postman", "El mismo de siempre"),
    (r"android studio", "Android Studio", "com.google.AndroidStudio", "El mismo de siempre"),
    (r"7-zip|winrar|winzip", "Archivos comprimidos", None, "Ya viene en Quantum: doble clic en el archivo"),
    (r"acrobat reader|foxit", "Visor de documentos", None, "Ya viene en Quantum"),
]

# Navegadores de Linux: clave → (nombres de la app, carpetas de perfil nativa y flatpak)
CHROMIUM = {
    "chrome": ("Google Chrome", "com.google.Chrome", [CONFIG / "google-chrome", HOME / ".var/app/com.google.Chrome/config/google-chrome"]),
    "edge": ("Microsoft Edge", "com.microsoft.Edge", [CONFIG / "microsoft-edge", HOME / ".var/app/com.microsoft.Edge/config/microsoft-edge"]),
    "brave": ("Brave", "com.brave.Browser", [CONFIG / "BraveSoftware/Brave-Browser", HOME / ".var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"]),
    "opera": ("Opera", "com.opera.Opera", [CONFIG / "opera", HOME / ".var/app/com.opera.Opera/config/opera"]),
}


# ------------------------------------------------------------------ utilidades

def run(cmd, timeout=60):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except (OSError, subprocess.SubprocessError) as e:
        return 1, str(e)


def user_dir(name, fallback):
    code, out = run(["xdg-user-dir", name])
    p = Path(out) if code == 0 and out and out != str(HOME) else HOME / fallback
    p.mkdir(parents=True, exist_ok=True)
    return p


def load_settings():
    try:
        return json.loads(SETTINGS.read_text())
    except (OSError, ValueError):
        return {}


def save_settings(s):
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    tmp = SETTINGS.with_suffix(".tmp")
    tmp.write_text(json.dumps(s, indent=4, ensure_ascii=False))
    tmp.replace(SETTINGS)


def running(name):
    return run(["pgrep", "-x", name])[0] == 0


def find_exports():
    """Pendrives montados con una copia de «Pasar a Quantum»: [(carpeta, manifest)]."""
    out = []
    roots = [Path("/var/lib/quantum/migrate"),      # la copia que dejó la instalación automática
             Path("/run/media") / os.environ.get("USER", ""), Path("/media") / os.environ.get("USER", ""), Path("/media"), Path("/mnt")]
    extra = os.environ.get("QUANTUM_MIGRATE_ROOTS")      # para pruebas: carpetas separadas por «:»
    if extra:
        roots = [Path(p) for p in extra.split(":")] + roots
    seen = set()
    for r in roots:
        try:
            cands = [r] + [p for p in r.iterdir() if p.is_dir()]
        except OSError:
            continue
        for mnt in cands:
            base = mnt / FOLDER
            m = base / "manifest.json"
            if m.is_file() and base not in seen:
                try:
                    out.append((base, json.loads(m.read_text())))
                    seen.add(base)
                except (OSError, ValueError):
                    pass
    return out


def done_ids():
    try:
        return set(DONE.read_text().split())
    except OSError:
        return set()


def mark_done(mid):
    DONE.parent.mkdir(parents=True, exist_ok=True)
    with DONE.open("a") as f:
        f.write(mid + "\n")


def suggest_apps(names):
    """Programas de Windows → [{name, flatpak, note, from}] sin repetir."""
    out, seen = [], set()
    for win in names:
        low = win.lower()
        for pat, name, fid, note in APPS:
            if re.search(pat, low):
                key = fid or name
                if key not in seen:
                    seen.add(key)
                    out.append({"name": name, "flatpak": fid, "note": note, "from": win})
                break
    return out


def installed_flatpaks():
    code, out = run(["flatpak", "list", "--app", "--columns=application"], timeout=30)
    return set(out.split()) if code == 0 else set()


def summary(base, m):
    """Lo que trae el pendrive, para la pantalla «Encontramos tus cosas»."""
    files = sum(f.get("files", 0) for f in m.get("folders", []))
    size = sum(f.get("bytes", 0) for f in m.get("folders", []))
    wifi = []
    if m.get("wifi"):
        try:
            wifi = json.loads((base / m["wifi"]).read_text())
        except (OSError, ValueError):
            pass
    return {
        "computer": m.get("computer", ""), "name": m.get("user", {}).get("name", ""),
        "created": m.get("created", ""), "complete": bool(m.get("complete")),
        "files": files, "bytes": size, "folders": [f["title"] for f in m.get("folders", [])],
        "picture": str(base / m["account"]["picture"]) if m.get("account", {}).get("picture") else "",
        "wallpaper": str(base / m["account"]["wallpaper"]) if m.get("account", {}).get("wallpaper") else "",
        "settings": bool(m.get("settings")),
        "browsers": [b["title"] for b in m.get("browsers", [])],
        "wifi": [w.get("ssid", "") for w in wifi],
        "steam": [{"name": g["name"], "bytes": g.get("bytes", 0)} for g in m.get("steam", [])],
        "apps": suggest_apps(m.get("apps", [])),
    }


# -------------------------------------------------------------------- copia

class Copier:
    """Copia árboles con avance; nunca pisa; une las partes «.qpartNNN» de FAT32."""

    def __init__(self, base, manifest, progress):
        self.base = Path(base)
        self.split = {s["path"]: s for s in manifest.get("split", [])}
        self.progress = progress           # progress(bytes_copiados_desde_el_inicio, texto)
        self.done = 0
        self.cancelled = False

    def _target(self, dst, size):
        """Dónde dejar el archivo: el mismo nombre si no existe o es igual; si no, «(Windows)»."""
        if not dst.exists():
            return dst, False
        try:
            if dst.stat().st_size == size:
                return dst, True              # ya estaba (por ejemplo, se pasó antes)
        except OSError:
            pass
        stem, suf = dst.stem, dst.suffix
        for i in range(1, 100):
            cand = dst.with_name(f"{stem} (Windows{'' if i == 1 else ' ' + str(i)}){suf}")
            if not cand.exists():
                return cand, False
            if cand.stat().st_size == size:
                return cand, True
        return dst.with_name(f"{stem} (Windows {int(time.time())}){suf}"), False

    def _stream(self, sources, dst, label):
        tmp = dst.with_name(dst.name + ".pasando")
        dst.parent.mkdir(parents=True, exist_ok=True)
        with open(tmp, "wb") as out:
            for src in sources:
                with open(src, "rb") as f:
                    while chunk := f.read(4 << 20):
                        if self.cancelled:
                            out.close(); tmp.unlink(missing_ok=True)
                            raise InterruptedError
                        out.write(chunk)
                        self.done += len(chunk)
                        self.progress(self.done, label)
        os.replace(tmp, dst)
        try:
            st = os.stat(sources[0])
            os.utime(dst, (st.st_atime, st.st_mtime))
        except OSError:
            pass

    def tree(self, rel_src, dst_root, label, errors):
        """Copia base/rel_src/* a dst_root. Devuelve cuántos archivos pasó."""
        src_root = self.base / rel_src
        n = 0
        if not src_root.is_dir():
            return 0
        for dirpath, _dirs, files in os.walk(src_root):
            for name in sorted(files):
                if name.endswith(".copiando"):
                    continue
                src = Path(dirpath) / name
                rel = src.relative_to(src_root)
                m = re.match(r"(.*)\.qpart(\d{3})$", name)
                try:
                    if m:
                        if m.group(2) != "001":
                            continue
                        whole = rel.with_name(m.group(1))
                        parts = sorted(src.parent.glob(re.escape(m.group(1)) + ".qpart[0-9][0-9][0-9]"))
                        size = sum(p.stat().st_size for p in parts)
                        dst, same = self._target(dst_root / whole, size)
                        if same:
                            self.done += size
                        else:
                            self._stream(parts, dst, f"{label}: {whole.name}")
                    else:
                        size = src.stat().st_size
                        dst, same = self._target(dst_root / rel, size)
                        if same:
                            self.done += size
                        else:
                            self._stream([src], dst, f"{label}: {name}")
                    n += 1
                except InterruptedError:
                    raise
                except OSError as e:
                    errors.append(f"{rel}: {e.strerror or e}")
        return n


# --------------------------------------------------------------- favoritos

def chromium_to_html(bookmarks_json, title):
    """Favoritos de Chrome/Edge/Brave → archivo HTML que importa cualquier navegador."""
    d = json.loads(Path(bookmarks_json).read_text())

    def node(n, depth):
        pad = "    " * depth
        if n.get("type") == "url":
            return f'{pad}<DT><A HREF="{html.escape(n.get("url", ""), quote=True)}">{html.escape(n.get("name", ""))}</A>\n'
        kids = "".join(node(c, depth + 1) for c in n.get("children", []))
        return f'{pad}<DT><H3>{html.escape(n.get("name", ""))}</H3>\n{pad}<DL><p>\n{kids}{pad}</DL><p>\n'

    roots = d.get("roots", {})
    body = "".join(node(roots[k], 1) for k in ("bookmark_bar", "other", "synced") if roots.get(k, {}).get("children"))
    return ("<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">\n"
            f"<TITLE>{html.escape(title)}</TITLE>\n<H1>{html.escape(title)}</H1>\n<DL><p>\n"
            f"    <DT><H3>{html.escape(title)}</H3>\n    <DL><p>\n{body}    </DL><p>\n</DL><p>\n")


def count_bookmarks(bookmarks_json):
    try:
        d = json.loads(Path(bookmarks_json).read_text())
    except (OSError, ValueError):
        return 0

    def c(n):
        return 1 if n.get("type") == "url" else sum(c(x) for x in n.get("children", []))
    return sum(c(r) for r in d.get("roots", {}).values() if isinstance(r, dict))


def merge_chromium(src_json, profile_dir, title):
    """Agrega los favoritos de Windows a un perfil de Chromium de Linux (sin borrar los que haya)."""
    profile_dir.mkdir(parents=True, exist_ok=True)
    dst = profile_dir / "Bookmarks"
    new = json.loads(Path(src_json).read_text())
    if not dst.exists():
        new.pop("checksum", None)
        dst.write_text(json.dumps(new, ensure_ascii=False, indent=3))
        return
    cur = json.loads(dst.read_text())
    folder = {"type": "folder", "name": title, "children": [], "date_added": "0", "id": "900000"}
    for k in ("bookmark_bar", "other", "synced"):
        folder["children"] += new.get("roots", {}).get(k, {}).get("children", [])
    cur.pop("checksum", None)
    cur.setdefault("roots", {}).setdefault("other", {"type": "folder", "name": "Otros favoritos", "children": []})
    cur["roots"]["other"].setdefault("children", []).append(folder)
    shutil.copy2(dst, dst.with_name("Bookmarks.antes-de-windows"))
    dst.write_text(json.dumps(cur, ensure_ascii=False, indent=3))


def firefox_profile(create=True):
    """Perfil principal de Firefox en Quantum (lo crea si Firefox nunca se abrió)."""
    base = HOME / ".mozilla" / "firefox"

    def read():
        ini = configparser.ConfigParser()
        if not ini.read(base / "profiles.ini"):
            return None
        for sec in ini.sections():
            if sec.startswith("Install") and ini[sec].get("Default"):
                return base / ini[sec]["Default"]
        for sec in ini.sections():
            if ini[sec].get("Default") == "1" and ini[sec].get("Path"):
                p = ini[sec]["Path"]
                return base / p if ini[sec].get("IsRelative", "1") == "1" else Path(p)
        return None
    p = read()
    if (p is None or not p.is_dir()) and create:
        # Firefox crea su perfil en el primer arranque: se abre sin ventana unos segundos
        try:
            proc = subprocess.Popen(["firefox", "--headless", "--no-remote", "about:blank"],
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            for _ in range(40):
                time.sleep(0.5)
                p = read()
                if p and (p / "prefs.js").exists():
                    break
            proc.terminate()
            proc.wait(timeout=10)
        except (OSError, subprocess.SubprocessError):
            pass
        p = read()
    return p if p and p.is_dir() else None


def firefox_is_fresh(profile):
    """True si el Firefox de Quantum todavía no tiene historial propio."""
    db = profile / "places.sqlite"
    if not db.exists():
        return True
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro&immutable=1", uri=True)
        n = con.execute("SELECT count(*) FROM moz_places WHERE visit_count > 0").fetchone()[0]
        con.close()
        return n == 0
    except sqlite3.Error:
        return False


def firefox_prefs(profile, prefs):
    """Agrega preferencias a prefs.js (Firefox cerrado)."""
    f = profile / "prefs.js"
    text = f.read_text() if f.exists() else ""
    for k, v in prefs.items():
        line = f'user_pref("{k}", {json.dumps(v)});'
        text = re.sub(rf'^user_pref\("{re.escape(k)}",.*\);\n?', "", text, flags=re.M)
        text += line + "\n"
    f.write_text(text)


# -------------------------------------------------------------------- Steam

def vdf_load(text):
    tokens = re.findall(r'"((?:[^"\\]|\\.)*)"|([{}])', text)
    root, stack, cur, key = {}, [], None, None
    cur = root
    for s, brace in tokens:
        if brace == "{":
            new = {}
            cur[key] = new
            stack.append(cur)
            cur, key = new, None
        elif brace == "}":
            cur = stack.pop() if stack else root
        elif key is None:
            key = s
        else:
            cur[key] = s
            key = None
    return root


def vdf_dump(d, depth=0):
    out = ""
    for k, v in d.items():
        pad = "\t" * depth
        if isinstance(v, dict):
            out += f'{pad}"{k}"\n{pad}{{\n{vdf_dump(v, depth + 1)}{pad}}}\n'
        else:
            out += f'{pad}"{k}"\t\t"{v}"\n'
    return out


def steam_root():
    for p in (DATA / "Steam", HOME / ".steam" / "steam"):
        if (p / "steamapps").is_dir() or p.is_dir():
            return p.resolve()
    return DATA / "Steam"


def steam_use_proton(root, appids):
    """Marca los juegos para que Steam los abra con Proton (son las versiones de Windows)."""
    cfg = root / "config" / "config.vdf"
    cfg.parent.mkdir(parents=True, exist_ok=True)
    d = vdf_load(cfg.read_text()) if cfg.exists() else {}
    steam = d.setdefault("InstallConfigStore", {}).setdefault("Software", {}).setdefault("Valve", {}).setdefault("Steam", {})
    m = steam.setdefault("CompatToolMapping", {})
    for a in appids:
        m.setdefault(a, {"name": "proton_experimental", "config": "", "priority": "250"})
    if cfg.exists():
        shutil.copy2(cfg, cfg.with_name("config.vdf.antes-de-windows"))
    cfg.write_text(vdf_dump(d))


# ------------------------------------------------------------------- pasos

class Importer:
    """Hace la importación por pasos; avisa el avance con on_step / on_progress."""

    def __init__(self, base, manifest, choices, on_step=None, on_progress=None):
        self.base = Path(base)
        self.m = manifest
        self.c = choices        # {folders, account, wifi, browsers, steam, apps:[flatpak ids]}
        self.on_step = on_step or (lambda key, state, detail: None)
        self.on_progress = on_progress or (lambda frac, text: None)
        self.results = {}       # key -> (ok, detalle)
        self.total = self._total()
        self.copier = Copier(self.base, manifest, self._copied)

    def _total(self):
        t = 0
        if self.c.get("folders"):
            t += sum(f.get("bytes", 0) for f in self.m.get("folders", []))
        if self.c.get("steam"):
            t += sum(g.get("bytes", 0) for g in self.m.get("steam", []))
        return max(t, 1)

    def _copied(self, done, text):
        self.on_progress(min(1.0, done / self.total), text)

    def steps(self):
        s = []
        if self.c.get("folders") and self.m.get("folders"):
            s.append(("folders", "Tus archivos"))
        if self.c.get("account") and (self.m.get("account") or self.m.get("settings")):
            s.append(("account", "Tu cuenta y tus ajustes"))
        if self.c.get("wifi") and self.m.get("wifi"):
            s.append(("wifi", "Redes Wi-Fi"))
        if self.c.get("browsers") and self.m.get("browsers"):
            s.append(("browsers", "Favoritos y contraseñas"))
        if self.c.get("steam") and self.m.get("steam"):
            s.append(("steam", "Juegos de Steam"))
        if self.c.get("apps"):
            s.append(("apps", "Tus apps"))
        return s

    def run(self):
        for key, _title in self.steps():
            if self.copier.cancelled:
                break
            self.on_step(key, "running", "")
            try:
                ok, detail = getattr(self, "do_" + key)()
            except InterruptedError:
                ok, detail = False, "Cancelado"
            except Exception as e:      # un paso que falla no frena a los demás
                ok, detail = False, f"No se pudo: {e}"
            self.results[key] = (ok, detail)
            self.on_step(key, "ok" if ok else "error", detail)
        self.on_progress(1.0, "")
        if not self.copier.cancelled:
            mark_done(self.m.get("id", ""))
        return self.results

    # ---- archivos
    def do_folders(self):
        dest = {
            "desktop": user_dir("DESKTOP", "Escritorio"), "documents": user_dir("DOCUMENTS", "Documentos"),
            "pictures": user_dir("PICTURES", "Imágenes"), "music": user_dir("MUSIC", "Música"),
            "videos": user_dir("VIDEOS", "Vídeos"), "downloads": user_dir("DOWNLOAD", "Descargas"),
        }
        errors, n = [], 0
        for f in self.m.get("folders", []):
            target = dest.get(f["key"]) or (HOME / "Juegos" / "Partidas guardadas de Windows")
            target.mkdir(parents=True, exist_ok=True)
            n += self.copier.tree(f["dir"], target, f["title"], errors)
        self.errors = errors
        detail = f"{n} archivos en sus carpetas" if n != 1 else "1 archivo en su carpeta"
        if errors:
            detail += f" · {len(errors)} no se pudieron pasar"
        return not errors or n > 0, detail

    # ---- cuenta
    def do_account(self):
        done, s = [], load_settings()
        acc, st = self.m.get("account", {}), self.m.get("settings") or {}
        pic = acc.get("picture")
        if pic and (self.base / pic).is_file():
            face = HOME / ".face"
            if face.exists():
                shutil.copy2(face, HOME / ".face.antes-de-windows")
            # .face se guarda como PNG (lo leen la pantalla de bloqueo y el inicio de sesión)
            if run(["magick", str(self.base / pic), "-resize", "512x512^", "-gravity", "center", "-extent", "512x512", f"png:{face}"])[0] != 0:
                shutil.copy2(self.base / pic, face)
            uid = os.getuid()
            run(["busctl", "call", "--system", "org.freedesktop.Accounts", f"/org/freedesktop/Accounts/User{uid}",
                 "org.freedesktop.Accounts.User", "SetIconFile", "s", str(face)], timeout=30)
            done.append("tu foto")
        name = self.m.get("user", {}).get("name", "")
        login = self.m.get("user", {}).get("login", "")
        if name and name != login:
            uid = os.getuid()
            run(["busctl", "call", "--system", "org.freedesktop.Accounts", f"/org/freedesktop/Accounts/User{uid}",
                 "org.freedesktop.Accounts.User", "SetRealName", "s", name], timeout=30)
        wall = acc.get("wallpaper")
        if wall and (self.base / wall).is_file():
            d = user_dir("PICTURES", "Imágenes") / "Fondos"
            d.mkdir(parents=True, exist_ok=True)
            ext = Path(wall).suffix or ".jpg"
            target = d / f"Fondo de Windows{ext}"
            shutil.copy2(self.base / wall, target)
            s.setdefault("appearance", {})["wallpaper"] = str(target)
            done.append("tu fondo")
        if st:
            s.setdefault("appearance", {})["mode"] = "dark" if st.get("dark") else "light"
            s.setdefault("clock", {})["format24h"] = bool(st.get("clock24h", True))
            done.append("modo oscuro" if st.get("dark") else "modo claro")
            kb = next((KEYBOARDS[k.lower()[-8:]] for k in st.get("keyboards", []) if k.lower()[-8:] in KEYBOARDS), None)
            if kb:
                s.setdefault("keyboard", {})["layout"], s["keyboard"]["variant"] = kb
                done.append("tu teclado")
        save_settings(s)
        run(["quantum-theme", "apply"], timeout=120)
        tz = TIMEZONES.get((st or {}).get("timezone", ""))
        if tz:
            cur = run(["timedatectl", "show", "-p", "Timezone", "--value"])[1]
            if cur != tz and run(["timedatectl", "set-timezone", tz], timeout=120)[0] == 0:
                done.append("tu zona horaria")
        if not done:
            return True, "Nada que cambiar"
        return True, ", ".join(done).capitalize()

    # ---- Wi-Fi
    def do_wifi(self):
        nets = json.loads((self.base / self.m["wifi"]).read_text())
        code, out = run(["nmcli", "-t", "-f", "NAME", "connection", "show"])
        have = set(out.splitlines()) if code == 0 else set()
        added, failed = 0, 0
        for w in nets:
            ssid, auth, key = w.get("ssid", ""), w.get("auth", "").lower(), w.get("key", "")
            if not ssid or ssid in have:
                continue
            cmd = ["nmcli", "connection", "add", "type", "wifi", "con-name", ssid, "ssid", ssid]
            if "sae" in auth or "wpa3" in auth:
                cmd += ["wifi-sec.key-mgmt", "sae", "wifi-sec.psk", key]
            elif key and auth not in ("open", ""):
                cmd += ["wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.psk", key]
            if run(cmd)[0] == 0:
                added += 1
            else:
                failed += 1
        detail = f"{added} redes guardadas" if added != 1 else "1 red guardada"
        if failed:
            detail += f" · {failed} no se pudieron agregar"
        return failed == 0, detail

    # ---- navegadores
    def do_browsers(self):
        done, notes = [], []
        docs = user_dir("DOCUMENTS", "Documentos")
        browsers = self.m.get("browsers", [])
        fx_from_windows = any(b["kind"] == "firefox" for b in browsers)
        html_for_firefox = None
        for b in browsers:
            src = self.base / b["dir"]
            if b["kind"] == "chromium":
                for prof in b.get("profiles", []):
                    bm = src / prof / "Bookmarks"
                    if not bm.is_file():
                        continue
                    title = f"Favoritos de {b['title']} (Windows)"
                    page = chromium_to_html(bm, title)
                    out = docs / f"{title}.html"
                    out.write_text(page)
                    html_for_firefox = html_for_firefox or out
                    # si el mismo navegador está (o se instaló) en Quantum, van directo a él
                    info = CHROMIUM.get(b["key"])
                    if info:
                        dirs = [d for d in info[2] if d.is_dir()]
                        installed = dirs or info[1] in installed_flatpaks() or info[1] in self.c.get("apps", [])
                        if installed:
                            target = (dirs[0] if dirs else (info[2][1] if info[1] in installed_flatpaks() or info[1] in self.c.get("apps", []) else info[2][0]))
                            merge_chromium(bm, target / ("Default" if b["key"] != "opera" else ""), title)
                done.append(f"{b['title']} ({count_bookmarks(src / b['profiles'][0] / 'Bookmarks') if b.get('profiles') else 0} favoritos)")
            else:
                if running("firefox"):
                    notes.append("Cierra Firefox y vuelve a pasar los navegadores para traer tu perfil")
                    continue
                prof = firefox_profile()
                if not prof:
                    notes.append("No se pudo preparar Firefox")
                    continue
                stamp = time.strftime("%Y%m%d-%H%M%S")
                keep = prof / f"antes-de-windows-{stamp}"
                for f in ("places.sqlite", "favicons.sqlite", "logins.json", "key4.db"):
                    if (src / f).is_file():
                        if (prof / f).exists():
                            keep.mkdir(exist_ok=True)
                            shutil.move(str(prof / f), str(keep / f))
                        for side in ("-wal", "-shm"):
                            (prof / (f + side)).unlink(missing_ok=True)
                        shutil.copy2(src / f, prof / f)
                done.append("Firefox (favoritos, historial y contraseñas)")
        # favoritos de Chrome/Edge en Firefox, si Firefox todavía no se usó y no vino su propio perfil
        if html_for_firefox and not fx_from_windows and not running("firefox"):
            prof = firefox_profile()
            if prof and firefox_is_fresh(prof):
                firefox_prefs(prof, {"browser.places.importBookmarksHTML": True, "browser.bookmarks.file": str(html_for_firefox)})
                done.append("y en Firefox")
        detail = ", ".join(done) if done else "Nada que pasar"
        if notes:
            detail += " · " + "; ".join(notes)
        return not notes, detail

    # ---- Steam
    def do_steam(self):
        if running("steam"):
            return False, "Cierra Steam y vuelve a intentarlo"
        root = steam_root()
        apps = root / "steamapps"
        (apps / "common").mkdir(parents=True, exist_ok=True)
        errors, ids = [], []
        for g in self.m.get("steam", []):
            target = apps / "common" / Path(g["dir"]).name
            self.copier.tree(g["dir"], target, g["name"], errors)
            man = self.base / g["manifest"]
            if man.is_file():
                text = man.read_text(errors="ignore")
                # que Steam no espere la carpeta de Windows (D:\SteamLibrary…)
                text = re.sub(r'\t"LauncherPath"\t+"[^"]*"\n', "", text)
                (apps / man.name).write_text(text)
                ids.append(g["appid"])
        if ids:
            steam_use_proton(root, ids)
        n = len(ids)
        detail = (f"{n} juegos listos" if n != 1 else "1 juego listo") + ": Steam los revisa la primera vez"
        if errors:
            detail += f" · {len(errors)} archivos no se pudieron pasar"
        return not errors, detail

    # ---- apps
    def do_apps(self):
        ids = [a for a in self.c.get("apps", []) if a]
        have = installed_flatpaks()
        run(["flatpak", "remote-add", "--user", "--if-not-exists", "flathub", "https://dl.flathub.org/repo/flathub.flatpakrepo"])
        ok, bad = 0, []
        for i, fid in enumerate(ids):
            if self.copier.cancelled:
                raise InterruptedError
            self.on_progress(i / max(1, len(ids)), f"Instalando {fid}")
            if fid in have:
                ok += 1
                continue
            if run(["flatpak", "install", "--user", "-y", "--noninteractive", "flathub", fid], timeout=1800)[0] == 0:
                ok += 1
            else:
                bad.append(fid)
        detail = f"{ok} apps instaladas" if ok != 1 else "1 app instalada"
        if bad:
            detail += f" · {len(bad)} no se pudieron instalar (revisa tu internet)"
        return not bad, detail
