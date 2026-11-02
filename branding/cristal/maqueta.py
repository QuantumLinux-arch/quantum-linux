#!/usr/bin/env python3
"""Maqueta del estilo «Cristal Cuántico»: cada panel es un cristal que refracta el fondo en los
bordes (como una lupa), lo desenfoca un poco, separa los colores en el borde y tiene un reflejo
de luz. Uso: maqueta.py FONDO SALIDA.png"""
import math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1920, 1080
bg_img = Image.open(sys.argv[1]).convert("RGB").resize((W, H), Image.LANCZOS)
BG = np.asarray(bg_img, np.float32) / 255
BLUR = np.asarray(bg_img.filter(ImageFilter.GaussianBlur(14)), np.float32) / 255
out = BG.copy()
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)
ROOT = "/home/telmop/dev/distro"
EB = f"{ROOT}/packages/quantum-migrate/windows/assets/Inter-ExtraBold.ttf"
TTC = "/usr/share/fonts/inter/Inter.ttc"
SYM = "/usr/share/fonts/TTF/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
F = lambda s, w="sb": ImageFont.truetype(EB, s) if w == "xb" else ImageFont.truetype(TTC, s, index={"r": 0, "m": 10, "sb": 12, "b": 14}[w])
S = lambda s: ImageFont.truetype(SYM, s)


def sample(img, x, y):
    xi = np.clip(x, 0, W - 1).astype(np.int32); yi = np.clip(y, 0, H - 1).astype(np.int32)
    return img[yi, xi]


def glass(x, y, w, h, r, bevel=26, refr=34, tint=0.10, light=(-0.6, -0.8), dim=0.86):
    """Cristal en el rectángulo redondeado (x, y, w, h, radio r) sobre `out`."""
    global out
    pad = 60
    x0, y0, x1, y1 = max(0, x - pad), max(0, y - pad), min(W, x + w + pad), min(H, y + h + pad)
    px, py = XX[y0:y1, x0:x1], YY[y0:y1, x0:x1]
    cx, cy = x + w / 2, y + h / 2
    qx, qy = np.abs(px - cx) - (w / 2 - r), np.abs(py - cy) - (h / 2 - r)
    ox, oy = np.maximum(qx, 0), np.maximum(qy, 0)
    sdf = np.hypot(ox, oy) + np.minimum(np.maximum(qx, qy), 0) - r          # <0 adentro
    # normal del borde (hacia afuera)
    nx = np.where(qx > 0, np.sign(px - cx) * ox, np.where(qx > qy, np.sign(px - cx), 0.0))
    ny = np.where(qy > 0, np.sign(py - cy) * oy, np.where(qy >= qx, np.sign(py - cy), 0.0))
    nl = np.hypot(nx, ny) + 1e-6; nx, ny = nx / nl, ny / nl
    inside = sdf < 0
    e = np.clip(-sdf / bevel, 0, 1)                                          # 0 en el borde, 1 adentro
    lens = (1 - e) ** 2.2
    region = out[y0:y1, x0:x1]
    # sombra suave alrededor
    shadow = np.clip(1 - np.maximum(sdf - 2, 0) / 38, 0, 1) ** 2 * (~inside) * 0.28
    region *= (1 - shadow)[..., None]
    # refracción con separación de colores en el borde
    rgb = np.zeros_like(region)
    for ch, k in ((0, 1.10), (1, 1.0), (2, 0.90)):
        d = refr * lens * k
        sx, sy = px + nx * d, py + ny * d
        rgb[..., ch] = sample(BLUR, sx, sy)[..., ch] * (0.55 + 0.45 * e) + sample(BG, sx, sy)[..., ch] * (0.45 - 0.45 * e)
    rgb = rgb * (1 - tint) + tint                                            # un toque blanco lechoso
    rgb = rgb * dim + 0.02                                                   # más oscuro donde hay texto
    # reflejo: el borde que mira a la luz brilla, y una franja suave arriba
    lx, ly = light; ll = math.hypot(lx, ly)
    facing = np.clip((nx * lx + ny * ly) / ll, 0, 1)
    spec = facing ** 3 * (1 - e) ** 1.5 * 0.85
    spec += np.clip(1 - (py - y) / (h * 0.55), 0, 1) ** 3 * 0.10
    rim = np.exp(-((sdf + 1.2) / 1.1) ** 2) * (0.35 + 0.65 * facing)
    rgb += (spec + rim)[..., None] * np.array([1.0, 0.98, 1.0])
    # tinte cuántico muy sutil en el borde opuesto a la luz
    back = np.clip((-nx * lx - ny * ly) / ll, 0, 1) * (1 - e) ** 2 * 0.22
    rgb += back[..., None] * np.array([0.42, 0.36, 1.0]) * 0.5
    aa = np.clip(-sdf + 0.5, 0, 1)[..., None]
    region[:] = region * (1 - aa) + np.clip(rgb, 0, 1) * aa


# ------------------------------------------------------------------ paneles
glass(760, 14, 400, 52, 26, bevel=18, refr=22, dim=0.62)        # isla (música)
glass(18, 16, 210, 46, 23, bevel=16, refr=18)                  # barra: app activa
glass(1452, 16, 450, 46, 23, bevel=16, refr=18)                # barra: estado y hora
glass(560, 980, 800, 78, 30, bevel=24, refr=30)                # dock
glass(560, 250, 800, 640, 38, bevel=34, refr=44, dim=0.66)      # menú de Inicio
glass(1452, 82, 450, 420, 36, bevel=30, refr=40, dim=0.70)      # panel de control
base_img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
img = Image.new("RGBA", (W, H))          # todo lo de encima va en una capa aparte y se mezcla al final
d = ImageDraw.Draw(img)
W_ = (255, 255, 255, 255); M_ = (235, 232, 250, 190)

# isla con música
art = Image.open(f"{ROOT}/build/assets/wallpapers/thumbs/biblioteca.jpg").convert("RGB").resize((38, 38))
m = Image.new("L", (38, 38)); ImageDraw.Draw(m).rounded_rectangle([0, 0, 37, 37], 10, fill=255)
img.paste(art, (768, 21), m)
d.text((816, 40), "Noche en órbita", font=F(16, "b"), fill=W_, anchor="lm")
for i, hgt in enumerate((14, 22, 10, 18)):
    c = [(79, 216, 255), (106, 92, 255), (177, 77, 255), (79, 216, 255)][i]
    d.rounded_rectangle([1112 + i * 8, 40 - hgt / 2, 1116 + i * 8, 40 + hgt / 2], 2, fill=c + (255,))
# barra
logo = Image.open("/tmp/claude-1000/qlogo.png").convert("RGBA").resize((26, 26)) if __import__("os").path.exists("/tmp/claude-1000/qlogo.png") else None
if logo: img.alpha_composite(logo, (34, 26))
d.text((70, 39), "Archivos", font=F(16, "b"), fill=W_, anchor="lm")
for i, ic in enumerate(("wifi", "bluetooth", "volume_up", "battery_5_bar")):
    d.text((1480 + i * 34, 39), ic, font=S(22), fill=W_, anchor="mm")
d.text((1680, 39), "21:47", font=F(17, "b"), fill=W_, anchor="lm")
d.text((1740, 39), "lun 2 nov", font=F(15, "m"), fill=M_, anchor="lm")
d.text((1872, 39), "power_settings_new", font=S(22), fill=W_, anchor="mm")
# panel de control
tiles = [("wifi", "Wi-Fi", "Casa"), ("bluetooth", "Bluetooth", "Audífonos"), ("sports_esports", "Modo juego", "Apagado"), ("dark_mode", "Modo oscuro", "Encendido")]
for i, (ic, t, s) in enumerate(tiles):
    tx, ty = 1476 + (i % 2) * 208, 106 + (i // 2) * 96
    d.rounded_rectangle([tx, ty, tx + 196, ty + 80], 22, fill=(255, 255, 255, 34 if i % 3 else 70), outline=(255, 255, 255, 60))
    d.text((tx + 34, ty + 40), ic, font=S(26), fill=W_, anchor="mm")
    d.text((tx + 62, ty + 30), t, font=F(16, "b"), fill=W_, anchor="lm")
    d.text((tx + 62, ty + 52), s, font=F(13, "m"), fill=M_, anchor="lm")
for j, (ic, v) in enumerate((("volume_up", 0.62), ("light_mode", 0.8))):
    sy = 316 + j * 70
    d.rounded_rectangle([1476, sy, 1876, sy + 48], 24, fill=(255, 255, 255, 30), outline=(255, 255, 255, 55))
    d.rounded_rectangle([1476, sy, 1476 + int(400 * v), sy + 48], 24, fill=(255, 255, 255, 120))
    d.text((1504, sy + 24), ic, font=S(22), fill=(30, 26, 50, 255), anchor="mm")
d.text((1476, 474), "Quantum Linux 1.0 «Quark»", font=F(13, "m"), fill=M_, anchor="lm")
# menú de Inicio
d.rounded_rectangle([592, 280, 1328, 336], 28, fill=(255, 255, 255, 40), outline=(255, 255, 255, 80))
d.text((624, 308), "search", font=S(24), fill=M_, anchor="mm")
d.text((650, 308), "Busca apps, juegos o ajustes…", font=F(17, "m"), fill=M_, anchor="lm")
apps = ["firefox", "steam", "discord", "spotify", "code", "obs", "gimp", "libreoffice-writer", "vlc", "org.gnome.Calculator",
        "telegram", "blender", "krita", "thunderbird", "inkscape", "kitty"]
names = ["Firefox", "Steam", "Discord", "Spotify", "VS Code", "OBS", "GIMP", "Writer", "VLC", "Calculadora", "Telegram", "Blender",
         "Krita", "Correo", "Inkscape", "Terminal"]
import os, subprocess
for i, a in enumerate(apps):
    gx, gy = 624 + (i % 6) * 118, 368 + (i // 6) * 136
    if i >= 12: break
    p = f"/usr/share/icons/Papirus/64x64/apps/{a}.svg"
    if os.path.exists(p):
        subprocess.run(["rsvg-convert", "-w", "64", p, "-o", "/tmp/claude-1000/ic.png"], check=False)
        img.alpha_composite(Image.open("/tmp/claude-1000/ic.png").convert("RGBA"), (gx + 10, gy))
    d.text((gx + 42, gy + 86), names[i], font=F(15, "sb"), fill=W_, anchor="mm")
d.line([(600, 790), (1320, 790)], fill=(255, 255, 255, 50), width=1)
d.ellipse([600, 812, 644, 856], fill=(106, 92, 255, 255))
d.text((622, 834), "S", font=F(20, "xb"), fill=W_, anchor="mm")
d.text((660, 834), "Sofía", font=F(17, "b"), fill=W_, anchor="lm")
d.text((1300, 834), "power_settings_new", font=S(24), fill=W_, anchor="mm")
# dock
dock_apps = ["system-file-manager", "firefox", "steam", "discord", "spotify", "code", "kitty"]
if logo: img.alpha_composite(logo.resize((34, 34)), (600, 1002))
for i, a in enumerate(dock_apps):
    p = f"/usr/share/icons/Papirus/64x64/apps/{a}.svg"
    if os.path.exists(p):
        subprocess.run(["rsvg-convert", "-w", "48", p, "-o", "/tmp/claude-1000/ic.png"], check=False)
        img.alpha_composite(Image.open("/tmp/claude-1000/ic.png").convert("RGBA"), (680 + i * 72, 995))
    if i in (1, 3):
        d.rounded_rectangle([698 + i * 72, 1046, 710 + i * 72, 1050], 2, fill=(255, 255, 255, 220))
# sombra suave del contenido, para que se lea sobre cualquier fondo
sh = Image.new("RGBA", (W, H), (10, 4, 20, 0)); sh.putalpha(img.getchannel("A").point(lambda v: int(v * 0.55)))
base_img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
base_img.alpha_composite(img)
base_img.convert("RGB").save(sys.argv[2], quality=95)
print("listo", sys.argv[2])
