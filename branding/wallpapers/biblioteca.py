#!/usr/bin/env python3
"""Fondo «Biblioteca» (original de Quantum): un pasillo de biblioteca infinito en perspectiva, con
estanterías llenas de libros rosados, crema, dorados y lilas, columnas y arcos dorados, una alfombra
rosada y un gran ventanal redondo al fondo. Niebla rosada, brillo suave y luces que flotan.

Uso: biblioteca.py CARPETA            → CARPETA/biblioteca.jpg (3840x2160) y thumbs/biblioteca.jpg
     biblioteca.py CARPETA --animado  → además CARPETA/animados/biblioteca.mp4 (bucle de 12 s, 1080p)
"""
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
ANIM = "--animado" in sys.argv
W, H = 3840, 2160
rng = np.random.default_rng(7)

# ---------------------------------------------------------------- cámara
CX, CY = W / 2, H * 0.47          # punto de fuga, un poco sobre el centro
F = W * 0.42                      # distancia focal
EYE = 1.55                        # altura de los ojos
HALF = 2.4                        # medio ancho del pasillo
TOP = 7.5                         # alto de las estanterías
Z0, Z1, BAY = 1.0, 60.0, 2.6      # profundidad cercana, lejana y largo de cada tramo


def P(x, y, z):
    return CX + F * x / z, CY - F * (y - EYE) / z


HAZE = np.array([255, 196, 222])  # niebla rosada


def fog(c, z, k=1.0):
    """Mezcla un color con la niebla según la distancia (perspectiva atmosférica)."""
    t = 1 - math.exp(-z / 16 * k)
    c = np.array(c, float)
    return tuple(int(v) for v in c * (1 - t) + HAZE * t)


BOOKS = [(214, 92, 150), (236, 132, 178), (248, 214, 196), (196, 152, 84), (232, 190, 110),
         (164, 120, 200), (128, 70, 140), (250, 236, 220), (190, 60, 110), (120, 84, 160)]


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


img = Image.new("RGB", (W, H))
d = ImageDraw.Draw(img, "RGBA")

# ------------------------------------------------------- techo y piso de fondo
for y in range(H):
    t = y / H
    if y < CY:
        k = (CY - y) / CY
        c = np.array([255, 205, 228]) * (1 - k) + np.array([92, 44, 92]) * k
    else:
        k = (y - CY) / (H - CY)
        c = np.array([250, 196, 214]) * (1 - k) + np.array([86, 40, 70]) * k
    d.line([(0, y), (W, y)], fill=tuple(int(v) for v in c))

# ------------------------------------------------- ventanal redondo al fondo
wx, wy = P(0, 3.6, Z1)
wr = F * 2.6 / Z1 * 9
glow = Image.new("L", (W, H))
gd = ImageDraw.Draw(glow)
for i in range(60):
    r = wr * (3.2 - i * 0.04)
    gd.ellipse([wx - r, wy - r, wx + r, wy + r], fill=int(4 + i * 1.6))
glow = glow.filter(ImageFilter.GaussianBlur(60))
img.paste((255, 236, 228), mask=glow)
d.ellipse([wx - wr, wy - wr, wx + wr, wy + wr], fill=(255, 246, 236))
for a in range(0, 180, 30):        # varillas del ventanal
    ang = math.radians(a)
    d.line([(wx - wr * math.cos(ang), wy - wr * math.sin(ang)), (wx + wr * math.cos(ang), wy + wr * math.sin(ang))],
           fill=(214, 168, 120, 150), width=6)
d.ellipse([wx - wr * 0.42, wy - wr * 0.42, wx + wr * 0.42, wy + wr * 0.42], outline=(214, 168, 120, 160), width=6)
d.ellipse([wx - wr, wy - wr, wx + wr, wy + wr], outline=(200, 150, 100, 200), width=14)

# ------------------------------------------------------------ tramos (de lejos a cerca)
zs = np.arange(Z0, Z1, BAY)[::-1]
for z in zs:
    za, zb = z, z + BAY
    for side in (-1, 1):
        x = side * HALF
        # fondo de la estantería (madera oscura)
        quad = [P(x, 0, za), P(x, TOP, za), P(x, TOP, zb), P(x, 0, zb)]
        d.polygon(quad, fill=fog((70, 34, 58), za))
        # repisas y libros
        rows = 6
        hrow = TOP / rows
        for r in range(rows):
            y0 = r * hrow + 0.08
            zz = za + 0.12
            while zz < zb - 0.12:
                bw = rng.uniform(0.09, 0.2)
                if zz + bw > zb - 0.12:
                    break
                bh = hrow * rng.uniform(0.62, 0.9)
                base = BOOKS[rng.integers(len(BOOKS))]
                lean = rng.random() < 0.06
                yt = y0 + bh
                c = fog(shade(base, rng.uniform(0.85, 1.1)), zz)
                q = [P(x, y0, zz), P(x, yt, zz + (0.06 if lean else 0)), P(x, yt, zz + bw + (0.06 if lean else 0)), P(x, y0, zz + bw)]
                d.polygon(q, fill=c)
                # franja dorada en el lomo
                if rng.random() < 0.55:
                    yy = y0 + bh * rng.uniform(0.6, 0.8)
                    d.line([P(x, yy, zz + 0.01), P(x, yy, zz + bw - 0.01)], fill=fog((236, 196, 120), zz), width=max(1, int(F * 0.025 / zz)))
                zz += bw + rng.uniform(0.0, 0.03)
            # repisa
            ys = r * hrow
            d.polygon([P(x, ys, za), P(x, ys + 0.08, za), P(x, ys + 0.08, zb), P(x, ys, zb)], fill=fog((150, 92, 70), za))
            d.polygon([P(x, ys + 0.08, za), P(x - side * 0.25, ys + 0.08, za), P(x - side * 0.25, ys + 0.08, zb), P(x, ys + 0.08, zb)],
                      fill=fog((176, 116, 88), za))
        # columna dorada al inicio del tramo
        cw = 0.22
        d.polygon([P(x - side * 0.05, 0, za), P(x - side * 0.05, TOP + 0.6, za), P(x - side * (0.05 + cw), TOP + 0.6, za),
                   P(x - side * (0.05 + cw), 0, za)], fill=fog((212, 166, 96), za))
        d.polygon([P(x - side * 0.05, 0, za), P(x - side * 0.05, TOP + 0.6, za), P(x - side * 0.05, TOP + 0.6, za + 0.18),
                   P(x - side * 0.05, 0, za + 0.18)], fill=fog((170, 120, 66), za))
    # arco dorado del techo
    pts = []
    for k in range(41):
        a = math.pi * k / 40
        pts.append(P(-HALF * math.cos(a) * 1.02, TOP + 0.6 + 2.6 * math.sin(a), za))
    d.line(pts, fill=fog((224, 178, 104), za), width=max(2, int(F * 0.12 / za)))
    # alfombra (rosada con borde dorado)
    d.polygon([P(-1.1, 0, za), P(1.1, 0, za), P(1.1, 0, zb), P(-1.1, 0, zb)], fill=fog((196, 70, 124), za, 0.8))
    for s in (-1, 1):
        d.polygon([P(s * 1.1, 0, za), P(s * 0.98, 0, za), P(s * 0.98, 0, zb), P(s * 1.1, 0, zb)], fill=fog((236, 190, 110), za, 0.8))
    # lámpara colgante con su luz
    lx, ly = P(0, TOP + 1.2, za + BAY / 2)
    lr = F * 0.12 / (za + BAY / 2)
    d.ellipse([lx - lr * 4, ly - lr * 4, lx + lr * 4, ly + lr * 4], fill=(255, 220, 170, 26))
    d.ellipse([lx - lr, ly - lr, lx + lr, ly + lr], fill=fog((255, 236, 200), za, 0.5))

# --------------------------------------------------------------- posproceso
a = np.asarray(img).astype(np.float32) / 255
# brillo: lo luminoso se difumina y suma
bright = np.clip((a - 0.72) / 0.28, 0, 1)
bl = np.asarray(Image.fromarray((bright * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(40)), np.float32) / 255
a = 1 - (1 - a) * (1 - bl * 0.55)
# rayos de luz desde el ventanal (difuminado radial simple)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
r = np.hypot((xx - wx) / W, (yy - wy) / H)
a += (np.exp(-r * 3.2) * 0.22)[..., None] * np.array([1.0, 0.86, 0.9])
# viñeta
v = 1 - 0.5 * np.clip(np.hypot((xx - W / 2) / (W * 0.62), (yy - H / 2) / (H * 0.62)) ** 2, 0, 1)
a *= v[..., None]
a = np.clip(a, 0, 1)
base = (a * 255).astype(np.uint8)


# luces que flotan (en el animado se mueven en bucle)
LIGHTS = [dict(x=rng.uniform(0, 1), y=rng.uniform(0.15, 0.95), r=rng.uniform(3, 12), k=int(rng.integers(1, 3)),
               ph=rng.uniform(0, 2 * math.pi), c=[(255, 220, 160), (255, 170, 210), (255, 240, 220)][int(rng.integers(3))])
          for _ in range(70)]


def lights(im, t, scale=1.0):
    """Puntos de luz suaves; t en [0, 1) da una vuelta completa (bucle perfecto)."""
    w, h = im.size
    lay = Image.new("RGBA", im.size)
    ld = ImageDraw.Draw(lay)
    for L in LIGHTS:
        ang = 2 * math.pi * t * L["k"] + L["ph"]
        x = (L["x"] + 0.012 * math.sin(ang)) * w
        y = (L["y"] - 0.02 * math.sin(ang * 0.5 + 1) - 0.01 * math.cos(ang)) * h
        rr = L["r"] * scale
        al = int(150 * (0.6 + 0.4 * math.sin(ang * 2)))
        ld.ellipse([x - rr * 3, y - rr * 3, x + rr * 3, y + rr * 3], fill=L["c"] + (al // 6,))
        ld.ellipse([x - rr, y - rr, x + rr, y + rr], fill=L["c"] + (al,))
    lay = lay.filter(ImageFilter.GaussianBlur(2 * scale))
    out = im.convert("RGBA")
    out.alpha_composite(lay)
    return out.convert("RGB")


os.makedirs(os.path.join(OUT, "thumbs"), exist_ok=True)
still = lights(Image.fromarray(base), 0.0, 2.0)
still.save(os.path.join(OUT, "biblioteca.jpg"), quality=92)
still.resize((480, 270), Image.LANCZOS).save(os.path.join(OUT, "thumbs", "biblioteca.jpg"), quality=88)
print("listo biblioteca.jpg")

if ANIM:
    os.makedirs(os.path.join(OUT, "animados", "thumbs"), exist_ok=True)
    small = Image.fromarray(base).resize((1920, 1080), Image.LANCZOS)
    path = os.path.join(OUT, "animados", "biblioteca.mp4")
    ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "1920x1080", "-r", "30",
                           "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "22", "-tune", "film", "-pix_fmt", "yuv420p",
                           "-movflags", "+faststart", "-an", path], stdin=subprocess.PIPE)
    N = 360
    for i in range(N):
        fr = lights(small, i / N, 1.0)
        if i == 0:
            fr.resize((480, 270), Image.LANCZOS).save(os.path.join(OUT, "animados", "thumbs", "biblioteca.jpg"), quality=88)
            fr.save(os.path.join(OUT, "animados", "biblioteca.jpg"), quality=90)
        ff.stdin.write(fr.tobytes())
    ff.stdin.close()
    ff.wait()
    print("listo animados/biblioteca.mp4", round(os.path.getsize(path) / 1e6, 1), "MB")
