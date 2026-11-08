"""Fuentes de apps de Quantum Store: repos de Arch, Flathub y AUR.

Cada fuente devuelve elementos con la misma forma:
    {key, source, id, name, summary, icon, installed, version, badge}
`icon` es una URL (http…) o "theme:<nombre>" para íconos del tema del sistema.
"""
import json
import os
import re
import subprocess
import time
import urllib.parse
import urllib.request
from pathlib import Path

CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "quantum-store"
UA = "QuantumStore/1.0 (+https://github.com/quantum-linux)"
C_ENV = {**os.environ, "LANG": "C", "LC_ALL": "C"}


def run(cmd, timeout=60):
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=C_ENV)
        return out.stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def http_json(url, data=None, ttl=3600, cache_name=None):
    """GET/POST JSON con caché en disco (ttl en segundos)."""
    path = CACHE / "http" / cache_name if cache_name else None
    if path and path.exists() and time.time() - path.stat().st_mtime < ttl:
        try:
            return json.loads(path.read_text())
        except ValueError:
            pass
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, headers={"User-Agent": UA, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            obj = json.load(r)
    except (OSError, ValueError):
        # sin internet: se usa la copia vieja si existe
        if path and path.exists():
            return json.loads(path.read_text())
        raise
    if path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(obj))
    return obj


def safe_name(s):
    return re.sub(r"[^A-Za-z0-9._-]", "_", s)


def item(source, id_, name, summary="", icon="", installed=False, version="", badge=""):
    return {"key": f"{source}:{id_}", "source": source, "id": id_, "name": name or id_,
            "summary": summary or "", "icon": icon or "theme:package-x-generic",
            "installed": bool(installed), "version": version or "", "badge": badge}


# ------------------------------------------------------------------ Arch

class Arch:
    label = "Arch"

    def installed(self):
        return set(run(["pacman", "-Qq"]).split())

    def search(self, q, limit=40):
        out = run(["pacman", "-Ss", "--", q])
        inst = self.installed()
        res, lines = [], out.splitlines()
        for i in range(0, len(lines) - 1, 2):
            head, desc = lines[i], lines[i + 1].strip()
            m = re.match(r"(\S+)/(\S+) (\S+)", head)
            if not m:
                continue
            repo, name, ver = m.groups()
            if repo not in ("core", "extra", "multilib"):
                continue
            res.append(item("arch", name, name, desc, f"theme:{name}", name in inst, ver, repo))
        # primero las coincidencias exactas o que empiezan igual
        ql = q.lower()
        res.sort(key=lambda x: (x["id"] != ql, not x["id"].startswith(ql), len(x["id"])))
        return res[:limit]

    def details(self, id_):
        info = {}
        key = None
        for line in run(["pacman", "-Si", "--", id_]).splitlines():
            if ":" in line and not line.startswith(" "):
                key, val = line.split(":", 1)
                key = key.strip()
                info[key] = val.strip()
            elif key:
                info[key] += " " + line.strip()
        inst = id_ in self.installed()
        return {**item("arch", id_, id_, info.get("Description", ""), f"theme:{id_}", inst,
                       info.get("Version", ""), info.get("Repository", "")),
                "description": info.get("Description", ""),
                "facts": [["Repositorio", info.get("Repository", "")], ["Versión", info.get("Version", "")],
                          ["Tamaño", info.get("Installed Size", "")], ["Licencia", info.get("Licenses", "")],
                          ["Web", info.get("URL", "")]],
                "screenshots": []}

    def install_cmd(self, id_):
        # -Syu: Arch no admite actualizaciones parciales (instalar con listas nuevas
        # sobre un sistema viejo puede romper bibliotecas)
        return ["pkexec", "pacman", "-Syu", "--needed", "--noconfirm", id_]

    def remove_cmd(self, id_):
        return ["pkexec", "pacman", "-Rns", "--noconfirm", id_, *addons(id_)]


def addons(id_, installed=None):
    """Paquetes de idioma de la app (firefox-i18n-es-cl, thunderbird-i18n-es-es, libreoffice-fresh-es…), que
    dependen de ella: sin quitarlos junto con la app, pacman se niega («breaks dependency»)."""
    if installed is None:
        try:
            installed = subprocess.run(["pacman", "-Qq"], capture_output=True, text=True, timeout=20).stdout.split()
        except (OSError, subprocess.SubprocessError):
            return []
    pre = re.escape(id_)
    pat = re.compile(rf"^{pre}-(i18n|langpack|l10n|lang)-[\w-]+$|^{pre}-(es|pt|en)(-[a-z]+)?$")
    return [p for p in installed if p != id_ and pat.match(p)]


# ---------------------------------------------------------------- Flathub

class Flathub:
    label = "Flathub"
    API = "https://flathub.org/api/v2"

    def installed(self):
        return set(run(["flatpak", "list", "--app", "--columns=application"]).split())

    def _from_hit(self, h, inst):
        return item("flathub", h["app_id"], h.get("name"), h.get("summary"), h.get("icon"),
                    h["app_id"] in inst, badge="Flathub")

    def search(self, q, limit=40):
        d = http_json(f"{self.API}/search", {"query": q}, ttl=1800, cache_name=f"fh-search-{safe_name(q)}.json")
        inst = self.installed()
        return [self._from_hit(h, inst) for h in d.get("hits", [])[:limit] if h.get("type", "desktop-application") != "runtime"]

    def collection(self, name, limit=18):
        d = http_json(f"{self.API}/collection/{name}?page=1&per_page={limit}", ttl=6 * 3600,
                      cache_name=f"fh-{safe_name(name)}.json")
        inst = self.installed()
        return [self._from_hit(h, inst) for h in d.get("hits", [])]

    def details(self, id_):
        d = http_json(f"{self.API}/appstream/{id_}", ttl=6 * 3600, cache_name=f"fh-app-{safe_name(id_)}.json")
        shots = []
        for s in d.get("screenshots", [])[:6]:
            sizes = [z for z in s.get("sizes", []) if isinstance(z, dict) and z.get("src")]
            # la más cercana a 750 px de ancho (nítida y liviana)
            sizes.sort(key=lambda z: abs(int(z.get("width") or 0) - 750))
            if sizes:
                shots.append(sizes[0]["src"])
        desc = re.sub(r"<[^>]+>", " ", d.get("description", "")).strip()
        desc = re.sub(r"\s+", " ", desc)
        rel = (d.get("releases") or [{}])[0]
        return {**item("flathub", id_, d.get("name"), d.get("summary"), d.get("icon"),
                       id_ in self.installed(), rel.get("version", ""), "Flathub"),
                "description": desc,
                "facts": [["Desarrollador", d.get("developer_name", "")], ["Versión", rel.get("version", "")],
                          ["Licencia", d.get("project_license", "")], ["Fuente", "Flathub"]],
                "screenshots": shots}

    def install_cmd(self, id_):
        return ["flatpak", "install", "--system", "-y", "--noninteractive", "flathub", id_]

    def remove_cmd(self, id_):
        return ["flatpak", "uninstall", "--system", "-y", "--noninteractive", id_]

    def launch_cmd(self, id_):
        return ["flatpak", "run", id_]


# -------------------------------------------------------------------- AUR

class Aur:
    label = "AUR"
    API = "https://aur.archlinux.org/rpc/v5"

    def installed(self):
        return set(run(["pacman", "-Qmq"]).split())

    def search(self, q, limit=30):
        if len(q) < 2:
            return []
        d = http_json(f"{self.API}/search/{urllib.parse.quote(q)}?by=name-desc", ttl=1800,
                      cache_name=f"aur-{safe_name(q)}.json")
        inst = self.installed()
        rs = sorted(d.get("results", []), key=lambda r: -float(r.get("Popularity") or 0))[:limit]
        return [item("aur", r["Name"], r["Name"], r.get("Description"), f"theme:{r['Name']}",
                     r["Name"] in inst, r.get("Version"), "Comunidad") for r in rs]

    def details(self, id_):
        d = http_json(f"{self.API}/info?arg[]={urllib.parse.quote(id_)}", ttl=1800, cache_name=f"aur-info-{safe_name(id_)}.json")
        r = (d.get("results") or [{}])[0]
        return {**item("aur", id_, id_, r.get("Description"), f"theme:{id_}", id_ in self.installed(),
                       r.get("Version"), "Comunidad"),
                "description": r.get("Description", ""),
                "facts": [["Mantenedor", r.get("Maintainer") or "Sin mantenedor"], ["Votos", str(r.get("NumVotes", ""))],
                          ["Versión", r.get("Version", "")],
                          ["Desactualizado", "Sí" if r.get("OutOfDate") else "No"], ["Web", r.get("URL") or ""]],
                "warning": "Este paquete lo publica la comunidad en AUR: no está revisado por Arch. "
                           "Se compila en tu PC y puede tardar varios minutos.",
                "screenshots": []}

    def install_cmd(self, id_):
        # yay compila con makepkg como usuario y usa pkexec solo para instalar
        return ["yay", "-S", "--noconfirm", "--answerdiff", "None", "--answerclean", "None",
                "--removemake", "--sudo", "pkexec", "--sudoflags", "", id_]

    def remove_cmd(self, id_):
        return ["pkexec", "pacman", "-Rns", "--noconfirm", id_, *addons(id_)]


SOURCES = {"arch": Arch(), "flathub": Flathub(), "aur": Aur()}
