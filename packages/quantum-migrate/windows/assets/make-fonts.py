#!/usr/bin/env python3
"""Genera las fuentes que se incrustan en «Pasar a Quantum.exe» (se corre a mano, con fonttools):
Inter en 3 pesos estáticos (solo latín) y los íconos de Material Symbols que usa la app, rellenos."""
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

ICONS = ["folder", "description", "image", "music_note", "movie", "download", "desktop_windows", "public",
         "person", "wallpaper", "wifi", "sports_esports", "apps", "check_circle", "usb", "arrow_forward",
         "arrow_back", "warning", "lock", "schedule", "close", "check", "hard_drive", "inventory_2",
         "rocket_launch", "bookmark", "info", "celebration", "folder_open", "dark_mode", "keyboard", "language",
         "account_circle", "save", "settings", "bolt", "error", "cancel", "home", "bookmarks", "palette", "star"]
SYM = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/quantum/MaterialSymbolsRounded.ttf"   # la instala quantum-shell
INTER = "/usr/share/fonts/inter/InterVariable.ttf"

def sub(font, unicodes, out):
    opts = subset.Options(); opts.layout_features = ["*"]; opts.name_IDs = ["*"]; opts.notdef_outline = True
    s = subset.Subsetter(opts); s.populate(unicodes=unicodes); s.subset(font); font.save(out)

for w, name in [(400, "Inter-Regular.ttf"), (600, "Inter-SemiBold.ttf"), (800, "Inter-ExtraBold.ttf")]:
    f = instancer.instantiateVariableFont(TTFont(INTER), {"wght": w, "opsz": 14} if "opsz" in [a.axisTag for a in TTFont(INTER)["fvar"].axes] else {"wght": w})
    sub(f, list(range(0x20, 0x7F)) + list(range(0xA0, 0x180)) + [0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2026, 0x20AC], name)
    print(name)

f = TTFont(SYM)
cmap = {g: cp for cp, g in f.getBestCmap().items()}
cps = [cmap[n] for n in ICONS]
f = instancer.instantiateVariableFont(f, {"FILL": 1, "wght": 500, "GRAD": 0, "opsz": 24})
sub(f, cps, "Icons.ttf")
with open("../src/icons.rs", "w") as o:
    o.write("// Generado por make-fonts.py: códigos de los íconos de Material Symbols\n")
    for n in ICONS:
        o.write(f"pub const {n.upper()}: &str = \"\\u{{{cmap[n]:x}}}\";\n")
print("Icons.ttf", len(cps), "íconos")
