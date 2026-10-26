#!/usr/bin/env python3
"""Centro Quantum: bienvenida y ajustes de Quantum Linux.

Guía la instalación (en el modo en vivo), instala paquetes de apps con un
clic, reúne los ajustes del escritorio (apariencia, fondos, ventanas,
teclado) y explica las equivalencias para quien viene de Windows.

Los ajustes se guardan con quantum-theme, que es quien los aplica.
"""
import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

from PyQt6.QtCore import Qt, QFileSystemWatcher, QProcess, QSize, QTimer, QUrl
from PyQt6.QtGui import QDesktopServices, QFont, QFontDatabase, QIcon, QPixmap
from PyQt6.QtWidgets import (
    QApplication, QButtonGroup, QCheckBox, QComboBox, QDialog, QFileDialog, QFrame,
    QGridLayout, QHBoxLayout, QLabel, QMainWindow, QMessageBox, QProgressBar, QPushButton,
    QScrollArea, QStackedWidget, QVBoxLayout, QWidget,
)

VERSION = "1.0"
CODENAME = "Quark"
LIVE = Path("/run/archiso").exists()
SHARE = Path(os.environ.get("QUANTUM_SHARE", "/usr/share/quantum"))
LOGOS = Path(os.environ.get("QUANTUM_LOGOS", SHARE / "logos"))
WALLPAPERS = Path(os.environ.get("QUANTUM_WALLPAPERS", "/usr/share/backgrounds/quantum"))
HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local" / "state")) / "quantum"
CENTER_CONF = CONFIG / "quantum" / "center.json"

# Paquetes de apps que se instalan con un clic.
# pacman: repositorios de Arch; flatpak: IDs de Flathub.
PACKS = [
    {
        "icon": "applications-games",
        "title": "Más juegos",
        "desc": "Epic, GOG y Battle.net con Heroic y Lutris, versiones de Proton "
                "personalizadas y Discord para jugar con amigos.",
        "apps": "Heroic · Lutris · ProtonUp-Qt · Discord · Bottles",
        "pacman": ["lutris"],
        "flatpak": ["com.heroicgameslauncher.hgl", "net.davidotek.pupgui2",
                    "com.discordapp.Discord", "com.usebottles.bottles"],
    },
    {
        "icon": "applications-multimedia",
        "title": "Creadores de contenido",
        "desc": "Graba, transmite y edita: todo lo que necesitas para YouTube, "
                "Twitch o TikTok.",
        "apps": "OBS Studio · Kdenlive · GIMP · Krita · Audacity · Inkscape",
        "pacman": ["obs-studio", "kdenlive", "gimp", "krita", "audacity", "inkscape"],
        "flatpak": [],
    },
    {
        "icon": "applications-development",
        "title": "Programación",
        "desc": "Editor de código, compiladores y los lenguajes más usados, "
                "listos para tu primer proyecto.",
        "apps": "VS Code (Code - OSS) · Git · Python · Node.js · base-devel",
        "pacman": ["code", "git", "base-devel", "python", "python-pip", "nodejs", "npm"],
        "flatpak": [],
    },
    {
        "icon": "applications-office",
        "title": "Oficina y estudio",
        "desc": "Documentos compatibles con Microsoft Office, correo y notas "
                "para el colegio, la universidad o el trabajo.",
        "apps": "LibreOffice · Thunderbird · Obsidian",
        "pacman": ["libreoffice-fresh", "libreoffice-fresh-es", "thunderbird", "thunderbird-i18n-es-es"],
        "flatpak": ["md.obsidian.Obsidian"],
    },
    {
        "icon": "multimedia-player",
        "title": "Música y video",
        "desc": "Reproduce cualquier formato y escucha tu música favorita.",
        "apps": "VLC · Spotify",
        "pacman": ["vlc", "vlc-plugins-all"],
        "flatpak": ["com.spotify.Client"],
    },
    {
        "icon": "internet-web-browser",
        "title": "Más navegadores",
        "desc": "Firefox ya viene instalado; agrega otros si los necesitas.",
        "apps": "Chromium · Brave",
        "pacman": ["chromium"],
        "flatpak": ["com.brave.Browser"],
    },
]

WINDOWS_EQUIV = [
    ("system-file-manager", "Explorador de archivos", "Archivos (Nautilus)", "Win + E"),
    ("preferences-system", "Configuración", "Centro Quantum → Ajustes", "Win + I"),
    ("quantum-store", "Microsoft Store", "Quantum Store", ""),
    ("utilities-system-monitor", "Administrador de tareas", "Mission Center", "Ctrl + Shift + Esc"),
    ("accessories-text-editor", "Bloc de notas", "Editor de texto", ""),
    ("applets-screenshooter", "Recortes", "Captura de región", "Win + Shift + S"),
    ("edit-paste", "Historial del portapapeles", "Portapapeles de Quantum", "Win + V"),
    ("utilities-terminal", "Símbolo del sistema / PowerShell", "Terminal (kitty)", "Ctrl + Alt + T"),
    ("view-grid", "Vista de tareas", "Vista de tareas (todos los escritorios)", "Win + Tab"),
    ("view-split-left-right", "Acoplar ventanas", "Acoplar a la mitad o maximizar", "Win + ← → ↑"),
    ("user-desktop", "Mostrar escritorio", "Mostrar escritorio", "Win + D"),
    ("steam", "Juegos de Steam", "Steam con Proton (ya instalado)", ""),
    ("system-reboot", "Restaurar sistema", "Puntos de restauración en el menú de arranque", ""),
]

KEYBOARDS = [
    ("", "Automático (el elegido al instalar)"),
    ("latam", "Español (Latinoamérica)"),
    ("es", "Español (España)"),
    ("us", "Inglés (EE. UU.)"),
    ("us,latam", "Inglés + Español (Latinoamérica)"),
    ("br", "Portugués (Brasil)"),
    ("pt", "Portugués (Portugal)"),
    ("fr", "Francés"),
    ("de", "Alemán"),
    ("it", "Italiano"),
    ("gb", "Inglés (Reino Unido)"),
]

# Paleta por defecto (la de quantum-theme sin colores dinámicos)
DEFAULT_COLORS = {
    "surface": "#13121c", "surface_container_low": "#1b1a24", "surface_container": "#1f1f28",
    "surface_container_high": "#2a2933", "surface_container_highest": "#35343e",
    "on_surface": "#e4e0ee", "on_surface_variant": "#c8c4d4", "outline_variant": "#474553",
    "primary": "#c5c0ff", "on_primary": "#2a1a9a", "primary_container": "#6a5cff",
    "on_primary_container": "#ffffff", "error": "#ffb4ab",
}


# ---------------------------------------------------------------- utilidades

def read_json(path):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return {}


def colors():
    return {**DEFAULT_COLORS, **read_json(STATE / "colors.json")}


def theme_get(key, default=None):
    try:
        out = subprocess.run(["quantum-theme", "get", key], capture_output=True, text=True, timeout=5)
        return json.loads(out.stdout) if out.returncode == 0 else default
    except (OSError, ValueError, subprocess.SubprocessError):
        return default


def theme_set(key, value):
    if isinstance(value, bool):
        value = "true" if value else "false"
    subprocess.Popen(["quantum-theme", "set", key, str(value)], start_new_session=True)


def run_in_terminal(title, command):
    """Ejecuta un comando en kitty para que se vea el progreso."""
    script = (
        f"echo -e '\\e[1;38;2;143;134;255m{title}\\e[0m\\n'; "
        f"{command}; status=$?; echo; "
        "if [ $status -eq 0 ]; then echo -e '\\e[1;32mListo.\\e[0m'; "
        "else echo -e '\\e[1;31mAlgo falló (código '$status').\\e[0m'; fi; "
        "read -rp 'Presiona Enter para cerrar...'"
    )
    subprocess.Popen(["kitty", "--title", title, "bash", "-c", script], start_new_session=True)


def launch(*cmd):
    try:
        subprocess.Popen(list(cmd), start_new_session=True)
    except FileNotFoundError:
        QMessageBox.warning(None, "Quantum", f"No se encontró «{cmd[0]}».")


def open_url(url):
    QDesktopServices.openUrl(QUrl(url))


def pack_command(pack):
    parts = []
    if pack["pacman"]:
        parts.append("sudo pacman -S --needed " + " ".join(map(shlex.quote, pack["pacman"])))
    if pack["flatpak"]:
        parts.append("flatpak install -y flathub " + " ".join(map(shlex.quote, pack["flatpak"])))
    return " && ".join(parts)


def stylesheet(c):
    return f"""
* {{ font-family: "Inter"; color: {c['on_surface']}; }}
QMainWindow, #content {{ background: {c['surface']}; }}
#sidebar {{ background: {c['surface_container_low']}; border-right: 1px solid {c['outline_variant']}; }}
#navButton {{
    text-align: left; padding: 10px 14px; border: none; border-radius: 12px;
    font-size: 14px; color: {c['on_surface_variant']}; background: transparent;
}}
#navButton:hover {{ background: {c['surface_container_high']}; color: {c['on_surface']}; }}
#navButton:checked {{ background: {c['primary_container']}; color: {c['on_primary_container']}; font-weight: 600; }}
#version {{ color: {c['on_surface_variant']}; font-size: 12px; }}
#h1 {{ font-size: 30px; font-weight: 800; }}
#h2 {{ font-size: 19px; font-weight: 700; }}
#lead {{ color: {c['on_surface_variant']}; font-size: 15px; }}
#muted {{ color: {c['on_surface_variant']}; font-size: 13px; }}
#apps {{ color: {c['primary']}; font-size: 12px; }}
#card {{ background: {c['surface_container']}; border: 1px solid {c['outline_variant']}; border-radius: 18px; }}
#heroCard {{
    border-radius: 22px; border: 1px solid {c['outline_variant']};
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
        stop:0 #2a2170, stop:0.55 #1b1840, stop:1 #13111f);
}}
/* el banner es siempre oscuro: texto claro también en modo claro */
#heroCard QLabel {{ color: #ffffff; background: transparent; }}
#heroCard QLabel#lead {{ color: #d6d1f2; }}
#heroCard QLabel#motto {{ color: #b9adff; font-size: 15px; font-weight: 700; }}
QPushButton {{
    background: {c['surface_container_high']}; border: 1px solid {c['outline_variant']};
    border-radius: 12px; padding: 8px 16px; font-size: 13px; font-weight: 600;
}}
QPushButton:hover {{ background: {c['surface_container_highest']}; }}
QPushButton:disabled {{ color: {c['on_surface_variant']}; }}
#primary {{
    border: none; color: #ffffff; padding: 10px 22px; font-size: 14px;
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 #4FD8FF, stop:0.5 #6A5CFF, stop:1 #B14DFF);
}}
#choice {{ border-radius: 14px; padding: 12px 18px; }}
#choice:checked {{ background: {c['primary_container']}; color: {c['on_primary_container']}; border-color: {c['primary']}; }}
#wall {{ border: 2px solid transparent; border-radius: 14px; padding: 3px; background: transparent; }}
#wall:checked {{ border-color: {c['primary']}; }}
#shortcut {{
    background: {c['surface_container_high']}; border: 1px solid {c['outline_variant']};
    border-radius: 8px; padding: 2px 8px; font-size: 12px; color: {c['primary']};
}}
QComboBox {{
    background: {c['surface_container_high']}; border: 1px solid {c['outline_variant']};
    border-radius: 12px; padding: 8px 14px; min-width: 260px;
}}
QComboBox QAbstractItemView {{ background: {c['surface_container_high']}; selection-background-color: {c['primary_container']}; }}
QCheckBox {{ color: {c['on_surface_variant']}; font-size: 13px; spacing: 8px; }}
QCheckBox::indicator {{ width: 18px; height: 18px; border-radius: 6px;
    border: 1px solid {c['outline_variant']}; background: {c['surface_container']}; }}
QCheckBox::indicator:checked {{ background: {c['primary']}; border-color: {c['primary']}; }}
QScrollArea {{ border: none; background: transparent; }}
QScrollBar:vertical {{ background: transparent; width: 10px; margin: 4px; }}
QScrollBar::handle:vertical {{ background: {c['outline_variant']}; border-radius: 3px; min-height: 30px; }}
QScrollBar::add-line, QScrollBar::sub-line {{ height: 0; }}
"""


def icon(name, size=40):
    if name.startswith("/"):
        lbl = QLabel()
        lbl.setPixmap(QPixmap(name).scaled(size, size, Qt.AspectRatioMode.KeepAspectRatio,
                                           Qt.TransformationMode.SmoothTransformation))
        lbl.setFixedSize(size, size)
        return lbl
    ic = QIcon.fromTheme(name)
    if ic.isNull():
        ic = QIcon.fromTheme("application-x-executable")
    lbl = QLabel()
    lbl.setPixmap(ic.pixmap(QSize(size, size)))
    lbl.setFixedSize(size, size)
    return lbl


def label(text, obj=None, wrap=True):
    lbl = QLabel(text)
    if obj:
        lbl.setObjectName(obj)
    lbl.setWordWrap(wrap)
    return lbl


def button(text, slot, primary=False):
    b = QPushButton(text)
    b.setCursor(Qt.CursorShape.PointingHandCursor)
    if primary:
        b.setObjectName("primary")
    b.clicked.connect(slot)
    return b


def card(obj="card"):
    f = QFrame()
    f.setObjectName(obj)
    lay = QVBoxLayout(f)
    lay.setContentsMargins(20, 18, 20, 18)
    lay.setSpacing(8)
    return f, lay


def page(title, lead):
    inner = QWidget()
    inner.setObjectName("content")
    lay = QVBoxLayout(inner)
    lay.setContentsMargins(40, 36, 40, 36)
    lay.setSpacing(16)
    if title:
        lay.addWidget(label(title, "h1"))
    if lead:
        lay.addWidget(label(lead, "lead"))
    scroll = QScrollArea()
    scroll.setWidgetResizable(True)
    scroll.setWidget(inner)
    return scroll, lay


def tile_grid(lay, items, live_disabled=False):
    """Cuadrícula de tarjetas (ícono, título, descripción, botón)."""
    grid = QGridLayout()
    grid.setSpacing(14)
    for i, (ic, title, desc, action, slot) in enumerate(items):
        c, cl = card()
        top = QHBoxLayout()
        top.addWidget(icon(ic, 38))
        top.addSpacing(6)
        top.addWidget(label(title, "h2"), 1)
        cl.addLayout(top)
        cl.addWidget(label(desc, "muted"))
        cl.addStretch()
        b = button(action, slot)
        if LIVE and live_disabled:
            b.setEnabled(False)
            b.setToolTip("Disponible después de instalar Quantum Linux")
        cl.addWidget(b, alignment=Qt.AlignmentFlag.AlignLeft)
        grid.addWidget(c, i // 2, i % 2)
    lay.addLayout(grid)


# ------------------------------------------------------------------- páginas

def home_page():
    w, lay = page(None, None)

    hero, hl = card("heroCard")
    hl.setContentsMargins(32, 30, 32, 30)
    row = QHBoxLayout()
    logo = QLabel()
    pm = QPixmap(str(LOGOS / "quantum-mark.png"))
    if not pm.isNull():
        logo.setPixmap(pm.scaledToHeight(104, Qt.TransformationMode.SmoothTransformation))
    row.addWidget(logo)
    row.addSpacing(20)
    text = QVBoxLayout()
    text.addWidget(label("Bienvenido a Quantum", "h1"))
    text.addWidget(label("Como Windows, pero mejor. Hecho con la comunidad.", "motto"))
    if LIVE:
        sub = ("Estás probando Quantum Linux sin instalar nada. Cuando quieras, "
               "instálalo en tu PC: toma unos 10 minutos.")
    else:
        sub = ("Tu PC está lista para jugar, crear y trabajar. "
               "Aquí tienes todo para dejarla a tu gusto.")
    text.addWidget(label(sub, "lead"))
    row.addLayout(text, 1)
    hl.addLayout(row)
    if LIVE:
        actions = QHBoxLayout()
        actions.addWidget(button("  Instalar Quantum Linux  ", lambda: launch("quantum-install"), primary=True))
        actions.addStretch()
        hl.addSpacing(8)
        hl.addLayout(actions)
    lay.addWidget(hero)

    lay.addSpacing(4)
    lay.addWidget(label("Empieza por aquí", "h2"))
    tile_grid(lay, [
        ("foton", "Juega", "Fotón junta tus juegos de Steam, Epic y GOG. Steam con Proton ya viene listo.",
         "Abrir Fotón", lambda: launch("foton")),
        ("quantum-store", "Instala apps", "Miles de apps, juegos y apps de Android, con un clic.",
         "Abrir Quantum Store", lambda: launch("quantum-store")),
        ("quantum-personalize", "Personaliza", "Cambia el aspecto, la barra, el dock y las ventanas al instante.",
         "Abrir Personalizar", open_personalize),
        ("system-software-update", "Actualiza", "Mantén tu sistema al día y seguro.",
         "Actualizar ahora", update_system),
    ])
    lay.addStretch()
    return w


def packs_page():
    w, lay = page("Configura tu PC",
                  "Elige qué quieres hacer y Quantum instala todo lo necesario. "
                  "Se abrirá una terminal para que veas el progreso.")
    grid = QGridLayout()
    grid.setSpacing(14)
    for i, pack in enumerate(PACKS):
        c, cl = card()
        top = QHBoxLayout()
        top.addWidget(icon(pack["icon"], 40))
        top.addSpacing(6)
        top.addWidget(label(pack["title"], "h2"), 1)
        cl.addLayout(top)
        cl.addWidget(label(pack["desc"], "muted"))
        cl.addWidget(label(pack["apps"], "apps"))
        cl.addStretch()
        b = button("Instalar", lambda _=False, p=pack: install_pack(p))
        if LIVE:
            b.setEnabled(False)
            b.setToolTip("Disponible después de instalar Quantum Linux")
        cl.addWidget(b, alignment=Qt.AlignmentFlag.AlignLeft)
        grid.addWidget(c, i // 2, i % 2)
    lay.addLayout(grid)
    lay.addStretch()
    return w


def choice_row(options, current, on_pick):
    """Fila de botones excluyentes (como un selector segmentado)."""
    row = QHBoxLayout()
    group = QButtonGroup(row)
    for value, text in options:
        b = QPushButton(text)
        b.setObjectName("choice")
        b.setCheckable(True)
        b.setChecked(value == current)
        b.setCursor(Qt.CursorShape.PointingHandCursor)
        b.clicked.connect(lambda _=False, v=value: on_pick(v))
        group.addButton(b)
        row.addWidget(b)
    row.addStretch()
    row._group = group  # mantener la referencia viva
    return row


def settings_page():
    w, lay = page("Ajustes", "Teclado, pantallas, red, sonido y más. Para cambiar cómo se ve tu escritorio, usa Personalizar.")

    # Lo visual vive en Personalizar (Quantum Shell)
    c, cl = card("heroCard")
    top = QHBoxLayout()
    top.addWidget(icon("quantum-personalize", 48))
    top.addSpacing(8)
    col = QVBoxLayout()
    col.addWidget(label("Personalizar", "h2"))
    col.addWidget(label("Estilos de un clic, modo claro u oscuro, color de acento, fondo de pantalla, "
                        "barra de tareas, ventanas y animaciones. También con Super + P.", "muted"))
    top.addLayout(col, 1)
    top.addWidget(button("Abrir Personalizar", open_personalize, primary=True))
    cl.addLayout(top)
    lay.addWidget(c)

    # Teclado
    c, cl = card()
    cl.addWidget(label("Teclado", "h2"))
    cl.addWidget(label("Con varias distribuciones, cambia entre ellas con Alt + Shift.", "muted"))
    combo = QComboBox()
    cur = theme_get("keyboard.layout", "")
    for value, text in KEYBOARDS:
        combo.addItem(text, value)
        if value == cur:
            combo.setCurrentIndex(combo.count() - 1)
    combo.currentIndexChanged.connect(lambda _: theme_set("keyboard.layout", combo.currentData()))
    cl.addWidget(combo, alignment=Qt.AlignmentFlag.AlignLeft)
    lay.addWidget(c)

    # Más ajustes (apps dedicadas)
    lay.addWidget(label("Más ajustes", "h2"))
    tile_grid(lay, [
        ("video-display", "Pantallas", "Resolución, frecuencia, escala y varios monitores.",
         "Abrir", lambda: launch("wdisplays")),
        ("network-wireless", "Red", "Wi-Fi, cable, VPN y contraseñas guardadas.",
         "Abrir", lambda: launch("nm-connection-editor")),
        ("bluetooth", "Bluetooth", "Vincula audífonos, controles y teclados.",
         "Abrir", lambda: launch("blueman-manager")),
        ("audio-volume-high", "Sonido", "Parlantes, micrófono y volumen por app.",
         "Abrir", lambda: launch("pavucontrol")),
        ("preferences-desktop-font", "Apariencia de apps", "Fuentes, íconos y cursor de las apps GTK.",
         "Abrir", lambda: launch("nwg-look")),
    ])
    lay.addStretch()
    return w


def open_personalize():
    subprocess.Popen(["qs", "-c", "quantum", "ipc", "call", "shell", "personalize"])


def pick_wallpaper(parent):
    path, _ = QFileDialog.getOpenFileName(parent, "Elige un fondo de pantalla", str(HOME / "Imágenes"),
                                          "Imágenes (*.png *.jpg *.jpeg *.webp)")
    if path:
        subprocess.Popen(["quantum-theme", "wallpaper", path])


def migrate_card():
    """Pasar desde Windows: abre el asistente que trae lo copiado con «Pasar a Quantum»."""
    c, cl = card()
    row = QHBoxLayout()
    row.addWidget(icon("quantum-migrate", 56))
    row.addSpacing(12)
    col = QVBoxLayout()
    col.addWidget(label("Trae tus cosas de Windows", "h2"))
    col.addWidget(label("Tus archivos, tu foto, tu fondo, tus redes Wi-Fi, tus favoritos y hasta tus juegos de Steam. "
                        "Primero copias todo a un pendrive con «Pasar a Quantum» en Windows; después lo conectas aquí.", "muted"))
    row.addLayout(col, 1)
    btns = QVBoxLayout()
    btns.addWidget(button("Pasar mis cosas", lambda: subprocess.Popen(["quantum-migrate"]), primary=True))
    btns.addWidget(button("Preparar un pendrive", lambda: subprocess.Popen(["quantum-migrate", "--preparar"])))
    row.addLayout(btns)
    cl.addLayout(row)
    return c


def windows_page():
    w, lay = page("¿Vienes de Windows?",
                  "Casi todo tiene un equivalente. Esta es tu guía rápida.")
    if shutil.which("quantum-migrate"):
        lay.addWidget(migrate_card())
    c, cl = card()
    cl.setSpacing(2)
    for ic, win, quantum, keys in WINDOWS_EQUIV:
        row = QHBoxLayout()
        row.setContentsMargins(0, 8, 0, 8)
        row.addWidget(icon(ic, 30))
        row.addSpacing(10)
        left = label(win, "muted")
        left.setMinimumWidth(230)
        row.addWidget(left)
        row.addWidget(label("→", "muted", wrap=False))
        row.addSpacing(6)
        row.addWidget(label(f"<b>{quantum}</b>"), 1)
        if keys:
            row.addWidget(label(keys, "shortcut", wrap=False))
        cl.addLayout(row)
    lay.addWidget(c)

    tips, tl = card()
    tl.addWidget(label("Atajos que vas a usar todo el día", "h2"))
    for keys, text in [
        ("Windows", "Abre el menú de apps. Escribe para buscar y presiona Enter."),
        ("Win + A", "Centro de control: Wi-Fi, volumen, modo juego y notificaciones."),
        ("Win + X", "Apagar, reiniciar o cerrar sesión."),
        ("Win + L", "Bloquear la pantalla."),
        ("Win + G", "Modo juego: apaga los efectos para tener más FPS."),
        ("Alt + Tab", "Cambiar de ventana. Arrastra una ventana a un borde para acoplarla."),
    ]:
        row = QHBoxLayout()
        row.setContentsMargins(0, 4, 0, 4)
        key = label(keys, "shortcut", wrap=False)
        key.setMinimumWidth(90)
        key.setAlignment(Qt.AlignmentFlag.AlignCenter)
        row.addWidget(key)
        row.addSpacing(12)
        row.addWidget(label(text, "muted"), 1)
        tl.addLayout(row)
    tl.addSpacing(6)
    tl.addWidget(label("<b>Puntos de restauración:</b> antes de cada actualización Quantum guarda una copia "
                       "del sistema. Si algo sale mal, elígela en el menú de arranque.", "muted"))
    lay.addWidget(tips)
    lay.addStretch()
    return w


PERF = "/usr/lib/quantum/performance"


def performance_card():
    """Interruptor del modo rendimiento (repos de CachyOS + planificador para juegos)."""
    c, cl = card()
    row = QHBoxLayout()
    row.addWidget(icon("speedometer", 48))
    row.addSpacing(12)
    col = QVBoxLayout()
    col.addWidget(label("Modo rendimiento", "h2"))
    col.addWidget(label("Paquetes optimizados para tu procesador (repos de CachyOS) y un planificador "
                        "pensado para juegos. Se puede desactivar cuando quieras.", "muted"))
    state = label("", "apps")
    col.addWidget(state)
    row.addLayout(col, 1)
    btn = button("Activar", lambda: None, primary=True)
    row.addWidget(btn)
    cl.addLayout(row)

    def refresh():
        try:
            out = subprocess.run([PERF, "status"], capture_output=True, text=True, timeout=5).stdout
            st = dict(kv.split("=", 1) for kv in out.split())
        except (OSError, subprocess.SubprocessError, ValueError):
            st = {}
        on = st.get("repo") == "on" or st.get("sched") == "on"
        cpu = {"v4": "Procesador compatible (x86-64-v4)", "v3": "Procesador compatible (x86-64-v3)",
               "old": "Tu procesador solo admite el planificador para juegos"}.get(st.get("cpu"), "")
        state.setText(("Activado · " if on else "Desactivado · ") + cpu)
        btn.setText("Desactivar" if on else "Activar")
        btn.setProperty("on", on)

    def toggle():
        on = btn.property("on")
        run_in_terminal("Modo rendimiento", f"sudo {PERF} {'disable' if on else 'enable'}")

    btn.clicked.connect(toggle)
    timer = QTimer(c, interval=4000, timeout=refresh)
    timer.start()
    refresh()
    return c


def system_page():
    w, lay = page("Sistema", "Mantenimiento en un clic.")
    lay.addWidget(performance_card())
    tile_grid(lay, [
        ("system-software-update", "Actualizar todo", "Sistema, drivers y apps de Flathub.",
         "Actualizar", update_system),
        ("document-revert", "Puntos de restauración", "Mira las copias guardadas del sistema.",
         "Ver", lambda: run_in_terminal("Puntos de restauración", "sudo snapper -c root list")),
        ("network-server", "Servidores más rápidos", "Busca los espejos de descarga más rápidos para ti.",
         "Buscar", lambda: run_in_terminal(
             "Espejos más rápidos",
             "sudo reflector --latest 20 --protocol https --sort rate "
             "--save /etc/pacman.d/mirrorlist && echo 'Espejos actualizados'")),
        ("edit-clear-all", "Liberar espacio", "Borra paquetes viejos de la caché.",
         "Limpiar", lambda: run_in_terminal(
             "Liberar espacio", "sudo paccache -rk1 && sudo paccache -ruk0 && flatpak uninstall --unused -y")),
        ("utilities-system-monitor", "Mi PC", "Procesador, gráfica, memoria y uso en tiempo real.",
         "Abrir", lambda: launch("missioncenter")),
        ("utilities-terminal", "Información del sistema", "Un resumen bonito para compartir tu escritorio.",
         "Mostrar", lambda: run_in_terminal("Quantum Linux", "fastfetch")),
    ], live_disabled=True)
    lay.addStretch()
    return w


# Quienes hacen Quantum. Los nombres se completan cuando cada colaborador lo autorice.
CREDITS = [
    ("quantum-linux", "@quantum.os", "Creador del proyecto", "Idea, diseño y desarrollo de Quantum Linux."),
    ("/usr/share/quantum/credits/lauty.png", "Lauty", "Multiusos",
     "Primer colaborador oficial. Creó el Discord de Quantum (discord.gg/qWmEb9xHkZ) y ayuda en todo lo que haga falta."),
    ("/usr/share/quantum/credits/interactive-proyects.png", "Interactive proyects", "Diseño web",
     "Mejoró la página web de Quantum: modo oscuro, animaciones y una versión más cómoda para celular."),
]
OPEN_SOURCE = ["Arch Linux", "Wayfire", "Quickshell", "Calamares", "matugen", "Papirus",
               "Material Symbols", "Inter", "Waydroid", "CachyOS"]


def credits_page():
    w, lay = page("Créditos", "Quantum Linux existe gracias a estas personas. Hecho con la comunidad.")
    grid = QGridLayout()
    grid.setSpacing(14)
    for i, (ic, name, role, desc) in enumerate(CREDITS):
        c, cl = card("heroCard" if i == 0 else "card")
        cl.addWidget(icon(ic, 56), alignment=Qt.AlignmentFlag.AlignHCenter)
        n = label(name, "h2")
        n.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        cl.addWidget(n)
        r = label(role.upper(), "apps")
        r.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        cl.addWidget(r)
        d = label(desc, "muted")
        d.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        cl.addWidget(d)
        grid.addWidget(c, i // 2, i % 2)
    lay.addLayout(grid)
    lay.addWidget(label("Y a todos los que comentan, prueban y comparten: cada idea ayuda a decidir "
                        "qué llega en la próxima versión.", "lead"))
    lay.addSpacing(8)
    lay.addWidget(label("Construido sobre software libre", "h2"))
    lay.addWidget(label(" · ".join(OPEN_SOURCE), "muted"))
    lay.addStretch()
    return w


def community_page():
    w, lay = page("Comunidad",
                  "Quantum Linux es libre y lo hacemos entre todos. Pregunta, reporta errores o comparte tu escritorio.")
    links = [
        ("discord", "Discord", "Pregunta, ayuda a otros, comparte tus estilos y colabora con el proyecto.",
         "https://discord.gg/qWmEb9xHkZ"),
        ("web-browser", "Página web", "Novedades, capturas y descargas.", "https://quantumlinux-arch.github.io"),
        ("github", "GitHub", "Código, errores y sugerencias.", "https://github.com/QuantumLinux-arch"),
        ("tiktok", "TikTok", "El diario de cómo se crea Quantum: @quantum.os", "https://www.tiktok.com/@quantum.os"),
        ("help-browser", "Wiki de Arch", "La documentación más completa de Linux (Quantum se basa en Arch).",
         "https://wiki.archlinux.org/title/Main_page_(Espa%C3%B1ol)"),
        ("applications-games", "ProtonDB", "Revisa qué tan bien corre un juego antes de comprarlo.",
         "https://www.protondb.com"),
    ]
    for ic, title, desc, url in links:
        c, cl = card()
        row = QHBoxLayout()
        row.addWidget(icon(ic, 40))
        row.addSpacing(10)
        col = QVBoxLayout()
        col.addWidget(label(title, "h2"))
        col.addWidget(label(desc, "muted"))
        row.addLayout(col, 1)
        row.addWidget(button("Abrir", lambda _=False, u=url: open_url(u)))
        cl.addLayout(row)
        lay.addWidget(c)
    lay.addStretch()
    return w


# ------------------------------------------------------------------ acciones

def update_system():
    # quantum-update muestra qué cambia (primero las mejoras de Quantum) y avisa a la barra
    launch("quantum-update")


def install_pack(pack):
    run_in_terminal(f"Instalando: {pack['title']}", pack_command(pack))


# ------------------------------------------------- apps elegidas al instalar
# El instalador deja en PENDING_APPS las apps de «Tus apps» que no se instalaron
# durante la instalación (porque eligieron «Al primer inicio» o no había internet).
PENDING_APPS = Path(os.environ.get("QUANTUM_PENDING_APPS", "/var/lib/quantum/pending-apps"))
APPS_DONE = STATE / "apps-done"
APP_ICONS = SHARE / "app-icons"   # íconos de Flathub de las apps del instalador


AI_PENDING = Path(os.environ.get("QUANTUM_AI_PENDING", "/var/lib/quantum/ai-model"))


def pending_apps():
    try:
        rows = [l.split("\t", 1) for l in PENDING_APPS.read_text().splitlines() if l.strip()]
    except OSError:
        rows = []
    try:
        model = AI_PENDING.read_text().strip()
        if model:
            rows.append(["ai:" + model, "Asistente con IA"])
    except OSError:
        pass
    done = set(APPS_DONE.read_text().split()) if APPS_DONE.exists() else set()
    return [(r[0], r[1] if len(r) > 1 else r[0]) for r in rows if r[0] not in done]


class PendingAppsDialog(QDialog):
    """Instala (de Flathub, para este usuario) las apps elegidas en el instalador."""

    def __init__(self, apps, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Terminando de instalar tus apps")
        self.setMinimumWidth(540)
        self.setSizeGripEnabled(False)
        self.apps = apps
        self.i = -1
        self.failed = []
        lay = QVBoxLayout(self)
        lay.setContentsMargins(28, 26, 28, 24)
        lay.setSpacing(12)
        lay.addWidget(label("Terminando de instalar tus apps", "h1"))
        lay.addWidget(label("Son las que elegiste al instalar Quantum. Puedes seguir usando tu PC mientras tanto.", "lead"))
        self.rows = []
        c, cl = card()
        cl.setSpacing(12)
        for app_id, name in apps:
            row = QHBoxLayout()
            png = APP_ICONS / ("quantum-assistant.png" if app_id.startswith("ai:") else f"{app_id}.png")
            row.addWidget(icon(str(png) if png.exists() else "package-x-generic", 36))
            row.addSpacing(6)
            row.addWidget(label(name, "h2"), 1)
            st = label("En espera", "muted", wrap=False)
            row.addWidget(st)
            cl.addLayout(row)
            self.rows.append(st)
        lay.addWidget(c)
        self.bar = QProgressBar()
        self.bar.setRange(0, len(apps))
        self.bar.setTextVisible(False)
        self.bar.setFixedHeight(8)
        lay.addWidget(self.bar)
        self.info = label("", "muted")
        lay.addWidget(self.info)
        btns = QHBoxLayout()
        btns.addStretch()
        self.retry = button("Reintentar", self.start)
        self.retry.hide()
        self.close_btn = button("Ocultar", self.hide)
        btns.addWidget(self.retry)
        btns.addWidget(self.close_btn)
        lay.addLayout(btns)
        self.proc = QProcess(self)
        self.proc.finished.connect(self.one_done)
        QTimer.singleShot(300, self.start)

    def start(self):
        self.retry.hide()
        self.failed = []
        self.i = -1
        subprocess.run(["flatpak", "remote-add", "--user", "--if-not-exists", "flathub",
                        "https://dl.flathub.org/repo/flathub.flatpakrepo"], capture_output=True)
        self.next()

    def next(self):
        self.i += 1
        if self.i >= len(self.apps):
            return self.finish()
        if self.rows[self.i].text() == "Lista":
            return self.next()
        self.rows[self.i].setText("Descargando…")
        self.info.setText(f"Instalando {self.apps[self.i][1]} ({self.i + 1} de {len(self.apps)})")
        app_id = self.apps[self.i][0]
        if app_id.startswith("ai:"):
            # modelo de Ollama (el servicio ya quedó activado por el instalador)
            self.proc.start("ollama", ["pull", app_id[3:]])
        else:
            self.proc.start("flatpak", ["install", "--user", "-y", "--noninteractive", "flathub", app_id])

    def one_done(self, code, _status):
        app_id = self.apps[self.i][0]
        if code == 0:
            self.rows[self.i].setText("Lista")
            APPS_DONE.parent.mkdir(parents=True, exist_ok=True)
            with APPS_DONE.open("a") as f:
                f.write(app_id + "\n")
        else:
            self.rows[self.i].setText("No se pudo")
            self.failed.append(app_id)
        self.bar.setValue(self.i + 1)
        self.next()

    def finish(self):
        app = QApplication.instance()
        app.setQuitOnLastWindowClosed(True)
        if not any(w.isVisible() for w in app.topLevelWidgets() if w is not self):
            # el Centro ya se cerró: avisar con una notificación y salir
            msg = "Algunas apps no se pudieron instalar" if self.failed else "Tus apps ya están listas"
            subprocess.Popen(["notify-send", "-i", "quantum-linux", "Quantum", msg])
            return app.quit()
        if self.failed:
            self.info.setText("Algunas apps no se pudieron instalar. Revisa tu conexión a internet y prueba otra vez. "
                              "Si cierras, lo intentaremos de nuevo la próxima vez que entres.")
            self.retry.show()
            self.close_btn.setText("Cerrar")
        else:
            self.info.setText("¡Listo! Tus apps ya están en el menú de inicio.")
            self.close_btn.setText("Listo")
        self.show()

    def closeEvent(self, e):
        # si se cierra mientras descarga, sigue en segundo plano
        if self.proc.state() != QProcess.ProcessState.NotRunning:
            e.ignore()
            self.hide()
        else:
            super().closeEvent(e)


# ------------------------------------------------------------------- ventana

class CenterWindow(QMainWindow):
    instance = None
    PAGES = [
        ("inicio", "go-home", "Inicio", home_page),
        ("apps", "package-x-generic", "Configura tu PC", packs_page),
        ("ajustes", "preferences-system", "Ajustes", settings_page),
        ("windows", "preferences-desktop-display", "Vengo de Windows", windows_page),
        ("sistema", "computer", "Sistema", system_page),
        ("comunidad", "system-users", "Comunidad", community_page),
        ("creditos", "applications-development", "Créditos", credits_page),
    ]

    def __init__(self, conf):
        super().__init__()
        CenterWindow.instance = self
        self.conf = conf
        self.setWindowTitle("Centro Quantum")
        self.setWindowIcon(QIcon.fromTheme("quantum-linux"))
        self.resize(1100, 720)
        self.setMinimumSize(900, 600)

        root = QWidget()
        rl = QHBoxLayout(root)
        rl.setContentsMargins(0, 0, 0, 0)
        rl.setSpacing(0)

        sidebar = QFrame()
        sidebar.setObjectName("sidebar")
        sidebar.setFixedWidth(250)
        sl = QVBoxLayout(sidebar)
        sl.setContentsMargins(16, 24, 16, 20)
        sl.setSpacing(4)

        wordmark = QLabel()
        dark = colors().get("mode", "dark") != "light"
        pm = QPixmap(str(LOGOS / ("quantum-wordmark-light.png" if dark else "quantum-wordmark-dark.png")))
        if not pm.isNull():
            wordmark.setPixmap(pm.scaledToWidth(190, Qt.TransformationMode.SmoothTransformation))
        else:
            wordmark.setText("Quantum")
            wordmark.setObjectName("h1")
        sl.addWidget(wordmark)
        sl.addSpacing(24)

        self.stack = QStackedWidget()
        self.buttons = {}
        group = QButtonGroup(self)
        for i, (key, ic, title, factory) in enumerate(self.PAGES):
            b = QPushButton("  " + title)
            b.setObjectName("navButton")
            b.setIcon(QIcon.fromTheme(ic))
            b.setIconSize(QSize(20, 20))
            b.setCheckable(True)
            b.setCursor(Qt.CursorShape.PointingHandCursor)
            b.clicked.connect(lambda _=False, idx=i: self.stack.setCurrentIndex(idx))
            group.addButton(b)
            sl.addWidget(b)
            self.buttons[key] = (i, b)
            self.stack.addWidget(factory())
        sl.addStretch()

        if not LIVE:
            auto = QCheckBox("Mostrar al iniciar sesión")
            auto.setChecked(conf.get("autostart", True))
            auto.toggled.connect(self.set_autostart)
            sl.addWidget(auto)
            sl.addSpacing(8)
        sl.addWidget(label(f"Quantum Linux {VERSION} «{CODENAME}»" + (" · en vivo" if LIVE else ""), "version"))

        rl.addWidget(sidebar)
        rl.addWidget(self.stack, 1)
        self.setCentralWidget(root)
        self.go("inicio")

    def go(self, key):
        idx, b = self.buttons.get(key, self.buttons["inicio"])
        b.setChecked(True)
        self.stack.setCurrentIndex(idx)

    def set_autostart(self, on):
        self.conf["autostart"] = on
        CENTER_CONF.parent.mkdir(parents=True, exist_ok=True)
        CENTER_CONF.write_text(json.dumps(self.conf, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description="Centro Quantum")
    parser.add_argument("--autostart", action="store_true",
                        help="modo inicio de sesión: no abre si el usuario lo desactivó")
    parser.add_argument("--page", default="inicio",
                        help="página inicial: inicio, apps, ajustes, windows, sistema, comunidad")
    parser.add_argument("--screenshot", metavar="ARCHIVO",
                        help="guarda una captura de cada página (para desarrollo)")
    args, qt_args = parser.parse_known_args()

    conf = read_json(CENTER_CONF)
    if args.autostart and not LIVE and not conf.get("autostart", True) and not pending_apps():
        return 0

    app = QApplication([sys.argv[0]] + qt_args)
    app.setApplicationName("quantum-center")
    app.setDesktopFileName("quantum-center")
    if "Inter" in QFontDatabase.families():
        app.setFont(QFont("Inter", 10))
    app.setStyleSheet(stylesheet(colors()))

    # Los colores cambian en vivo cuando quantum-theme los regenera (fondo, modo claro/oscuro)
    watcher = QFileSystemWatcher(app)
    colors_file = STATE / "colors.json"

    def watch():
        STATE.mkdir(parents=True, exist_ok=True)
        for path in (str(STATE), str(colors_file)):
            if Path(path).exists() and path not in watcher.files() + watcher.directories():
                watcher.addPath(path)

    def restyle(*_):
        app.setStyleSheet(stylesheet(colors()))
        watch()  # quantum-theme reemplaza el archivo: hay que volver a vigilarlo

    debounce = QTimer(app, singleShot=True, interval=120, timeout=restyle)
    watcher.fileChanged.connect(lambda *_: debounce.start())
    watcher.directoryChanged.connect(lambda *_: debounce.start())
    watch()

    win = CenterWindow(conf)
    if args.screenshot:
        win.show()
        base = Path(args.screenshot)
        for key, *_ in CenterWindow.PAGES:
            win.go(key)
            app.processEvents()
            win.grab().save(str(base.with_name(f"{base.stem}-{key}{base.suffix}")))
        return 0
    win.go(args.page)
    win.show()
    if not LIVE:
        apps = pending_apps()
        if apps:
            dlg = PendingAppsDialog(apps, win)
            dlg.show()
            # cerrar el Centro no corta las descargas: se sale al terminar
            app.setQuitOnLastWindowClosed(False)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
