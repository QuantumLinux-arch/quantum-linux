"""Fotón: reúne los juegos instalados de Steam, Heroic (Epic, GOG, Amazon), del sistema
y de Windows (carpeta ~/Juegos y los que agregues), y la tienda con el catálogo de Quantum.

Cada juego: {key, source, id, name, cover, hero, icon, lastPlayed, launch}
`cover`/`hero` son rutas locales (file://) o URLs; `icon` es un nombre del tema.
"""
import configparser
import json
import os
import re
import shutil
import subprocess
import tarfile
import time
import urllib.parse
import urllib.request
from pathlib import Path

HOME = Path.home()
DATA = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local" / "share"))
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local" / "state")) / "quantum"
HISTORY = STATE / "foton.json"
UA = "Foton/1.0 (Quantum Linux)"

STEAM_ROOTS = [DATA / "Steam", HOME / ".steam" / "steam",
               HOME / ".var/app/com.valvesoftware.Steam/.local/share/Steam"]
HEROIC_ROOTS = [CONFIG / "heroic", HOME / ".var/app/com.heroicgameslauncher.hgl/config/heroic"]
# herramientas de Steam que no son juegos
STEAM_TOOLS = re.compile(r"^(Proton|Steam Linux Runtime|Steamworks Common|SteamVR|Steam Audio)", re.I)
STEAM_CDN = "https://shared.steamstatic.com/store_item_assets/steam/apps"
CATALOG_DIR = Path(os.environ.get("FOTON_CATALOG", "/usr/share/quantum/foton"))
PENDING_GAMES = Path(os.environ.get("QUANTUM_PENDING_GAMES", "/var/lib/quantum/pending-games"))
FOTON_DATA = DATA / "quantum" / "foton"            # juegos de Windows agregados y sus prefijos
WIN_GAMES = FOTON_DATA / "games.json"
PREFIXES = FOTON_DATA / "prefixes"
GAMES_DIR = HOME / "Juegos"                        # cada carpeta con un .exe es un juego
COVERS_CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "quantum" / "foton-covers.json"


# ------------------------------------------------------------------ utilidades

def parse_vdf(text):
    """Parser mínimo del formato KeyValues de Steam (.vdf / .acf)."""
    tokens = re.findall(r'"((?:[^"\\]|\\.)*)"|([{}])', text)
    stack, cur, key = [], {}, None
    for s, brace in tokens:
        if brace == "{":
            new = {}
            cur[key] = new
            stack.append(cur)
            cur, key = new, None
        elif brace == "}":
            cur = stack.pop() if stack else cur
        elif key is None:
            key = s
        else:
            cur[key] = s
            key = None
    return cur


def history():
    try:
        return json.loads(HISTORY.read_text())
    except (OSError, ValueError):
        return {}


def remember(key):
    h = history()
    h[key] = int(time.time())
    HISTORY.parent.mkdir(parents=True, exist_ok=True)
    HISTORY.write_text(json.dumps(h))


def file_url(p):
    return "file://" + str(p) if p else ""


def game(source, id_, name, launch, cover="", hero="", icon="", last=0):
    return {"key": f"{source}:{id_}", "source": source, "id": str(id_), "name": name,
            "cover": cover, "hero": hero, "icon": icon or "applications-games",
            "lastPlayed": int(last or 0), "launch": launch}


# ---------------------------------------------------------------------- Steam

def steam_root():
    for r in STEAM_ROOTS:
        if (r / "steamapps").is_dir():
            return r.resolve()
    return None


def steam_art(root, appid, kind):
    """Arte local de la biblioteca de Steam (dos formatos de caché) o el del CDN."""
    cache = root / "appcache" / "librarycache"
    for p in (cache / str(appid) / f"{kind}.jpg", cache / f"{appid}_{kind}.jpg"):
        if p.exists():
            return file_url(p)
    return f"{STEAM_CDN}/{appid}/{kind}.jpg"


def steam_games():
    root = steam_root()
    if not root:
        return []
    libs = {root}
    try:
        vdf = parse_vdf((root / "steamapps" / "libraryfolders.vdf").read_text(errors="ignore"))
        for v in vdf.get("libraryfolders", {}).values():
            if isinstance(v, dict) and v.get("path"):
                libs.add(Path(v["path"]))
    except OSError:
        pass
    out, seen = [], set()
    flatpak = ".var/app/com.valvesoftware.Steam" in str(root)
    for lib in libs:
        for acf in (lib / "steamapps").glob("appmanifest_*.acf"):
            try:
                st = parse_vdf(acf.read_text(errors="ignore")).get("AppState", {})
            except OSError:
                continue
            appid, name = st.get("appid"), st.get("name", "")
            if not appid or appid in seen or STEAM_TOOLS.match(name):
                continue
            # bit 4 = totalmente instalado
            if not int(st.get("StateFlags", "0")) & 4:
                continue
            seen.add(appid)
            url = f"steam://rungameid/{appid}"
            launch = (["flatpak", "run", "com.valvesoftware.Steam", url] if flatpak else ["steam", url])
            out.append(game("steam", appid, name, launch,
                            cover=steam_art(root, appid, "library_600x900"),
                            hero=steam_art(root, appid, "library_hero"),
                            icon="steam", last=st.get("LastPlayed", 0)))
    return out


# --------------------------------------------------------------------- Heroic

def heroic_games():
    out = []
    for root in HEROIC_ROOTS:
        cache = root / "store_cache"
        if not cache.is_dir():
            continue
        flatpak = ".var/app" in str(root)
        for file, runner, label in (("legendary_library.json", "legendary", "epic"),
                                    ("gog_library.json", "gog", "gog"),
                                    ("nile_library.json", "nile", "amazon")):
            try:
                data = json.loads((cache / file).read_text())
            except (OSError, ValueError):
                continue
            items = data.get("library") or data.get("games") or []
            for g in items:
                if not g.get("is_installed") or not g.get("app_name"):
                    continue
                url = f"heroic://launch?appName={g['app_name']}&runner={runner}"
                launch = (["flatpak", "run", "com.heroicgameslauncher.hgl", url] if flatpak else ["xdg-open", url])
                out.append(game(label, g["app_name"], g.get("title") or g["app_name"], launch,
                                cover=g.get("art_cover") or g.get("art_square") or "",
                                hero=g.get("art_background") or g.get("art_cover") or "",
                                icon="heroic"))
        if out:
            break
    return out


# ------------------------------------------------------- juegos del sistema

def desktop_dirs():
    dirs = [DATA] + [Path(d) for d in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if d]
    dirs += [HOME / ".local/share/flatpak/exports/share", Path("/var/lib/flatpak/exports/share")]
    return [d / "applications" for d in dirs]


SKIP_IDS = {"steam", "com.valvesoftware.Steam", "heroic", "com.heroicgameslauncher.hgl", "foton",
            "net.davidotek.pupgui2", "lutris", "net.lutris.Lutris"}


def desktop_games():
    out, seen = [], set()
    for d in desktop_dirs():
        if not d.is_dir():
            continue
        for f in sorted(d.glob("*.desktop")):
            did = f.stem
            if did in seen or did in SKIP_IDS:
                continue
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(f, encoding="utf-8")
                e = cp["Desktop Entry"]
            except (configparser.Error, KeyError, UnicodeDecodeError):
                continue
            seen.add(did)
            cats = e.get("Categories", "")
            exec_ = e.get("Exec", "")
            if "Game" not in cats.split(";") or e.get("NoDisplay", "false") == "true" or e.get("Hidden", "false") == "true":
                continue
            if "steam://" in exec_ or "heroic://" in exec_:
                continue  # ya aparecen como juegos de Steam / Heroic
            name = e.get("Name[es]") or e.get("Name") or did
            out.append(game("local", did, name, ["gtk-launch", did], icon=e.get("Icon", "")))
    return out


def all_games(lookup=False):
    games = steam_games() + heroic_games() + desktop_games() + windows_games(lookup)
    h = history()
    # los juegos del catálogo instalados de Flathub usan el arte del catálogo
    art = {c["ref"]: c for c in catalog() if c["kind"] == "flathub"}
    for g in games:
        g["lastPlayed"] = max(g["lastPlayed"], h.get(g["key"], 0))
        c = art.get(g["id"]) if g["source"] == "local" else None
        if c:
            g.update(name=c["name"], cover=c["cover"], hero=c["hero"], source="foton", key="foton:" + g["id"])
    games.sort(key=lambda g: (-g["lastPlayed"], g["name"].lower()))
    return games


# ------------------------------------------------------ juegos de Windows
# Corren con umu-run (el mismo sistema que usa Steam) y Proton-GE, cada uno en su
# propio prefijo para que no se mezclen. umu descarga Proton solo la primera vez.

NOT_GAME_EXE = re.compile(r"(unins|uninstall|setup|install|redist|vcredist|vc_redist|dxsetup|directx|dotnet|"
                          r"crash|report|ue4prereq|prereq|update|patch|helper|config|launcherhelper|easyanticheat"
                          r"|battleye|cefprocess|notification|server)", re.I)


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-") or "juego"


def load_win_games():
    try:
        return json.loads(WIN_GAMES.read_text())
    except (OSError, ValueError):
        return []


def save_win_games(games):
    WIN_GAMES.parent.mkdir(parents=True, exist_ok=True)
    WIN_GAMES.write_text(json.dumps(games, ensure_ascii=False, indent=1))


def exe_candidates(folder, depth=4):
    """Ejecutables que parecen el juego (sin desinstaladores ni instaladores de librerías)."""
    out = []
    folder = Path(folder)
    for p in folder.rglob("*.exe"):
        try:
            rel = p.relative_to(folder)
        except ValueError:
            continue
        if len(rel.parts) > depth or NOT_GAME_EXE.search(p.stem):
            continue
        low = str(rel).lower()
        if any(x in low for x in ("windows/", "_commonredist", "redist/", "directx/", "support/")):
            continue
        try:
            out.append((p, p.stat().st_size))
        except OSError:
            pass
    def score(item):
        p, size = item
        name = slug(p.stem)
        bonus = 3 if name and name in slug(folder.name) else 0
        bonus += 1 if "64" in p.parent.name.lower() or "binaries" in str(p.parent).lower() else 0
        return (bonus, size)
    out.sort(key=score, reverse=True)
    return [p for p, _ in out]


def nice_name(folder):
    return re.sub(r"[_.]+", " ", Path(folder).name).strip()


def cover_lookup(name):
    """Busca la portada en Steam por nombre (sin cuenta ni clave). Se guarda en caché."""
    try:
        cache = json.loads(COVERS_CACHE.read_text())
    except (OSError, ValueError):
        cache = {}
    key = name.lower()
    if key in cache:
        return cache[key]
    appid = ""
    try:
        q = urllib.parse.quote(name)
        req = urllib.request.Request(f"https://store.steampowered.com/api/storesearch/?term={q}&l=spanish&cc=US",
                                     headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=10) as r:
            items = json.load(r).get("items") or []
        want = slug(name)
        for it in items[:5]:
            got = slug(it.get("name", ""))
            if got == want or (len(want) > 4 and (got.startswith(want) or want.startswith(got))):
                appid = str(it["id"])
                break
    except Exception:
        return ""          # sin internet: se reintenta la próxima vez
    cache[key] = appid
    COVERS_CACHE.parent.mkdir(parents=True, exist_ok=True)
    COVERS_CACHE.write_text(json.dumps(cache))
    return appid


def win_launch(exe, prefix, steamid=""):
    return ["env", f"WINEPREFIX={prefix}", f"GAMEID=umu-{steamid or 'default'}", "PROTONPATH=GE-Proton",
            "STORE=none", "umu-run", str(exe)]


def win_game(id_, name, exe, prefix, steamid="", last=0):
    cover = hero = ""
    if steamid:
        cover, hero = f"{STEAM_CDN}/{steamid}/library_600x900.jpg", f"{STEAM_CDN}/{steamid}/library_hero.jpg"
    g = game("windows", id_, name, win_launch(exe, prefix, steamid), cover, hero, icon="wine", last=last)
    g["exe"] = str(exe)
    return g


def windows_games(lookup=False):
    """Los agregados a mano y cada carpeta de ~/Juegos que tenga un .exe."""
    out, used = [], set()
    for w in load_win_games():
        if Path(w.get("exe", "")).exists():
            out.append(win_game(w["id"], w["name"], w["exe"], w["prefix"], w.get("steamid", "")))
            used.add(str(Path(w["exe"]).resolve()))
    if GAMES_DIR.is_dir():
        for d in sorted(p for p in GAMES_DIR.iterdir() if p.is_dir()):
            exes = exe_candidates(d)
            if not exes or any(str(e.resolve()) in used for e in exes):
                continue
            name = nice_name(d)
            steamid = cover_lookup(name) if lookup else ""
            out.append(win_game("dir-" + slug(d.name), name, exes[0], PREFIXES / slug(d.name), steamid))
    return out


def add_windows_game(name, exe, prefix=None):
    """Agrega un juego de Windows ya instalado (o recién instalado en su prefijo)."""
    games = load_win_games()
    id_ = slug(name)
    base, n = id_, 2
    while any(g["id"] == id_ for g in games):
        id_, n = f"{base}-{n}", n + 1
    games.append({"id": id_, "name": name, "exe": str(exe),
                  "prefix": str(prefix or PREFIXES / id_), "steamid": cover_lookup(name)})
    save_win_games(games)
    return id_


def remove_windows_game(id_):
    save_win_games([g for g in load_win_games() if g["id"] != id_])


def run_windows_installer(name, installer):
    """Ejecuta el instalador en un prefijo nuevo; al terminar devuelve (prefijo, candidatos)."""
    prefix = PREFIXES / slug(name)
    prefix.mkdir(parents=True, exist_ok=True)
    before = set(exe_candidates(prefix / "drive_c", depth=8)) if (prefix / "drive_c").is_dir() else set()
    cmd = win_launch(installer, prefix)
    subprocess.run(cmd, cwd=str(Path(installer).parent), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    drive = prefix / "drive_c"
    found = []
    for base in (drive / "Program Files", drive / "Program Files (x86)", drive / "Games", drive):
        if base.is_dir():
            depth = 8 if base != drive else 2
            found += [p for p in exe_candidates(base, depth) if p not in before and p not in found
                      and "windows" not in [x.lower() for x in p.parts]]
    return str(prefix), [str(p) for p in found[:8]]


# --------------------------------------------------------------- catálogo

def catalog():
    try:
        games = json.loads((CATALOG_DIR / "catalog.json").read_text())["games"]
    except (OSError, ValueError, KeyError):
        return []
    out = []
    for g in games:
        g = dict(g)
        if g["kind"] == "steam":
            g["cover"] = f"{STEAM_CDN}/{g['ref']}/library_600x900.jpg"
            g["hero"] = f"{STEAM_CDN}/{g['ref']}/library_hero.jpg"
        else:
            g["cover"] = file_url(CATALOG_DIR / "art" / f"{g['id']}-cover.jpg")
            g["hero"] = file_url(CATALOG_DIR / "art" / f"{g['id']}-hero.jpg")
        out.append(g)
    return out


def flatpak_installed():
    try:
        r = subprocess.run(["flatpak", "list", "--app", "--columns=application"],
                           capture_output=True, text=True, timeout=20)
        return set(r.stdout.split())
    except (OSError, subprocess.SubprocessError):
        return set()


def steam_installed_ids():
    return {g["id"] for g in steam_games()}


def pending_games():
    """Juegos elegidos en el instalador (los de Steam se instalan desde Fotón)."""
    try:
        return [l.split("\t")[0] for l in PENDING_GAMES.read_text().splitlines() if l.strip()]
    except OSError:
        return []


def install_flatpak(ref, progress=None):
    """Instala un juego de Flathub para este usuario; avisa el avance (0..1)."""
    subprocess.run(["flatpak", "remote-add", "--user", "--if-not-exists", "flathub",
                    "https://dl.flathub.org/repo/flathub.flatpakrepo"], capture_output=True)
    p = subprocess.Popen(["flatpak", "install", "--user", "-y", "--noninteractive", "flathub", ref],
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    buf = b""
    while chunk := p.stdout.read1(4096):
        buf = (buf + chunk)[-2048:]
        found = re.findall(rb"(\d{1,3})%", buf)
        if found and progress:
            progress(min(100, int(found[-1])) / 100)
    if p.wait() != 0:
        raise RuntimeError(buf.decode(errors="ignore")[-300:])
    return ref


def install_steam(appid):
    """Abre el diálogo de instalación de Steam (Steam se encarga de Proton)."""
    root = steam_root()
    flatpak = root is not None and ".var/app/com.valvesoftware.Steam" in str(root)
    url = f"steam://install/{appid}"
    cmd = ["flatpak", "run", "com.valvesoftware.Steam", url] if flatpak else ["steam", url]
    subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# ------------------------------------------------------------------ herramientas

MANGO_ENV = CONFIG / "environment.d" / "90-quantum-mangohud.conf"
MANGO_CONF = CONFIG / "MangoHud" / "MangoHud.conf"
MANGO_DEFAULT = """# Quantum Linux: FPS y uso de CPU/GPU en una línea discreta
horizontal
legacy_layout=0
fps
gpu_stats
cpu_stats
ram
frametime=0
hud_compact
round_corners=10
background_alpha=0.4
font_size=20
text_color=E4E0EE
gpu_color=4FD8FF
cpu_color=B14DFF
position=top-left
toggle_hud=Shift_R+F12
"""


def gamemode_on():
    return (STATE / "gamemode").exists()


def set_gamemode(on):
    subprocess.Popen(["quantum-theme", "gamemode", "on" if on else "off"])


def fps_on():
    return MANGO_ENV.exists()


def set_fps(on):
    if on:
        MANGO_ENV.parent.mkdir(parents=True, exist_ok=True)
        MANGO_ENV.write_text("MANGOHUD=1\n")
        if not MANGO_CONF.exists():
            MANGO_CONF.parent.mkdir(parents=True, exist_ok=True)
            MANGO_CONF.write_text(MANGO_DEFAULT)
    else:
        MANGO_ENV.unlink(missing_ok=True)


def compat_dir():
    root = steam_root() or (DATA / "Steam")
    return root / "compatibilitytools.d"


def proton_ge_installed():
    d = compat_dir()
    vers = sorted((p.name for p in d.glob("GE-Proton*") if p.is_dir()), reverse=True) if d.is_dir() else []
    return vers[0] if vers else ""


def proton_ge_latest():
    req = urllib.request.Request("https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest",
                                 headers={"User-Agent": UA, "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=20) as r:
        rel = json.load(r)
    tars = [a for a in rel["assets"] if a["name"].endswith(".tar.gz")]
    # la versión para PC (x86_64) se llama justo «<tag>.tar.gz»; hay otras para ARM
    asset = next((a for a in tars if a["name"] == f"{rel['tag_name']}.tar.gz"), None) \
        or next(a for a in tars if "aarch64" not in a["name"] and "arm" not in a["name"])
    return rel["tag_name"], asset["browser_download_url"], asset.get("size", 0)


def install_proton_ge(progress=None):
    """Descarga e instala la última versión de Proton-GE para Steam."""
    tag, url, size = proton_ge_latest()
    d = compat_dir()
    if (d / tag).is_dir():
        return tag
    d.mkdir(parents=True, exist_ok=True)
    tmp = d / f".{tag}.tar.gz"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r, open(tmp, "wb") as f:
        total = int(r.headers.get("Content-Length") or size or 0)
        done = 0
        while chunk := r.read(1 << 18):
            f.write(chunk)
            done += len(chunk)
            if progress and total:
                progress(done / total * 0.9)
    with tarfile.open(tmp) as t:
        t.extractall(d, filter="data")
    tmp.unlink(missing_ok=True)
    if progress:
        progress(1.0)
    return tag


def launch(g):
    env = dict(os.environ)
    if fps_on():
        env["MANGOHUD"] = "1"
    remember(g["key"])
    cmd = g["launch"]
    if cmd[0] == "gtk-launch" and not shutil.which("gtk-launch"):
        cmd = ["xdg-open", g["id"] + ".desktop"]
    # los de Windows arrancan desde su carpeta (muchos buscan ahí sus archivos)
    cwd = str(Path(g["exe"]).parent) if g.get("exe") else None
    subprocess.Popen(cmd, env=env, cwd=cwd, start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
