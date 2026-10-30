#!/usr/bin/env python3
# Fondo del estilo Serpantium: montañas rosadas en capas, estrellas y un brillo suave.
# Original de Quantum (generado por código). Uso: python3 fondo.py salida.png [ancho alto]
import sys, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
W, H = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (3840, 2160)
rnd = random.Random(7)

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# cielo
y = np.linspace(0, 1, H)[:, None]
top, mid, low = np.array([214, 130, 178]), np.array([238, 170, 205]), np.array([246, 196, 222])
sky = np.where(y < 0.55, top + (mid - top) * (y / 0.55), mid + (low - mid) * ((y - 0.55) / 0.45))
img = Image.fromarray(np.repeat(sky[:, None, :], W, axis=1).reshape(H, W, 3).astype(np.uint8), "RGB")

# brillo del sol detrás de las montañas
glow = Image.new("L", (W, H), 0)
gd = ImageDraw.Draw(glow)
cx, cy = int(W * 0.38), int(H * 0.42)
for r in range(int(H * 0.5), 0, -8):
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=int(120 * (1 - r / (H * 0.5)) ** 1.6))
img = Image.composite(Image.new("RGB", (W, H), (255, 228, 240)), img, glow.filter(ImageFilter.GaussianBlur(40)))

# estrellas
d = ImageDraw.Draw(img)
for _ in range(int(W * H / 26000)):
    x, yy = rnd.random() * W, rnd.random() * H * 0.45
    s = rnd.choice([1, 1, 1, 2, 2, 3]) * W / 1920
    d.ellipse([x - s, yy - s, x + s, yy + s], fill=(255, 240, 248))

def ridge(base, amp, seed, rough):
    r = random.Random(seed)
    ph = [r.random() * 6.28 for _ in range(6)]
    xs = np.arange(W + 1)
    v = np.zeros(W + 1)
    for k, f in enumerate([1.3, 2.7, 5.1, 9.8, 19, 37]):
        v += math.pow(rough, k) * np.sin(xs / W * f * math.pi + ph[k])
    # un pico marcado
    pk = r.uniform(0.25, 0.75) * W
    v += 1.4 * np.exp(-((xs - pk) / (W * r.uniform(0.08, 0.16))) ** 2)
    return base * H - v * amp * H

layers = [  # (base, amplitud, color, aspereza, árboles)
    (0.52, 0.07, (200, 120, 170), 0.55, False),
    (0.60, 0.08, (168, 88, 146), 0.6, False),
    (0.70, 0.07, (128, 58, 116), 0.6, True),
    (0.80, 0.06, (92, 36, 88), 0.55, True),
    (0.90, 0.05, (58, 20, 58), 0.5, True),
]
for i, (base, amp, col, rough, trees) in enumerate(layers):
    ys = ridge(base, amp, 100 + i, rough)
    poly = [(x, ys[x]) for x in range(0, W + 1, 4)] + [(W, H), (0, H)]
    # niebla entre capas
    fog = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(fog).polygon([(x, ys[x] - H * 0.02) for x in range(0, W + 1, 4)] + [(W, H), (0, H)], fill=(250, 210, 230, 60))
    img.paste(fog.filter(ImageFilter.GaussianBlur(H * 0.02)), (0, 0), fog.filter(ImageFilter.GaussianBlur(H * 0.02)))
    d = ImageDraw.Draw(img)
    d.polygon(poly, fill=col)
    if trees:
        n = int(W / (60 - i * 8))
        for _ in range(n):
            x = rnd.random() * W
            h = H * rnd.uniform(0.015, 0.035) * (1 + i * 0.35)
            gy = ys[int(x)] + rnd.uniform(0, H * 0.02)
            w = h * 0.38
            d.polygon([(x, gy - h), (x - w, gy + 2), (x + w, gy + 2)], fill=col)

img = img.filter(ImageFilter.GaussianBlur(0.6))
img.save(out)
print(out, img.size)
