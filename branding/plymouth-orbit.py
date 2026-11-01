#!/usr/bin/env python3
"""Imágenes de la órbita del arranque (Plymouth): órbita inclinada de 265x82 en un lienzo de
600x600 partida en mitad de atrás y de adelante, y los 30 puntos del cometa (cabeza blanca y
estela que pasa de cian a índigo y violeta, cada vez más chica y transparente).
Uso: plymouth-orbit.py CARPETA"""
import math, os, sys
from PIL import Image, ImageDraw

out = sys.argv[1]
S, C, RX, RY, TILT = 600, 300, 265, 82, math.radians(-24)
TRAIL = 30
COLS = [(79, 216, 255), (106, 92, 255), (177, 77, 255)]


def point(u):
    x, y = RX * math.cos(u), RY * math.sin(u)
    return C + x * math.cos(TILT) - y * math.sin(TILT), C + x * math.sin(TILT) + y * math.cos(TILT)


for half, rng in (("back", (math.pi, 2 * math.pi)), ("front", (0, math.pi))):
    big = Image.new("RGBA", (S * 2, S * 2))
    d = ImageDraw.Draw(big)
    pts = [tuple(2 * v for v in point(rng[0] + (rng[1] - rng[0]) * k / 120)) for k in range(121)]
    d.line(pts, fill=(197, 192, 255, 80), width=4)
    big.resize((S, S), Image.LANCZOS).save(os.path.join(out, f"orbit-{half}.png"))

for j in range(TRAIL):
    r = 7.0 - j * 0.17
    al = int(235 * (1 - j / TRAIL) ** 1.6)
    c = (255, 255, 255) if j == 0 else COLS[min(2, (j - 1) * 3 // (TRAIL - 1))]
    n = 32
    im = Image.new("RGBA", (n * 4, n * 4))
    d = ImageDraw.Draw(im)
    R = r * 4
    if j == 0:   # la cabeza brilla un poco
        d.ellipse([n * 2 - R * 1.9, n * 2 - R * 1.9, n * 2 + R * 1.9, n * 2 + R * 1.9], fill=(127, 227, 255, 70))
    d.ellipse([n * 2 - R, n * 2 - R, n * 2 + R, n * 2 + R], fill=c + (al,))
    im.resize((n, n), Image.LANCZOS).save(os.path.join(out, f"comet-{j:02d}.png"))
print("órbita de Plymouth lista")
