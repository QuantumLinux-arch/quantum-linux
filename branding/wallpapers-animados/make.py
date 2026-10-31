#!/usr/bin/env python3
"""Fondos animados de Quantum, hechos desde cero (sin material de terceros).
Cada uno es un bucle de 12 s que vuelve exactamente al principio (todo lo que se mueve
es periódico), así al repetirse no se nota el corte.

Uso: make.py CARPETA [nombre…]  → CARPETA/<nombre>.mp4, <nombre>.jpg (cuadro fijo) y thumbs/<nombre>.jpg
"""
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageFilter

W, H, FPS, T = 1920, 1080, 30, 12.0
N = int(FPS * T)
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
HERE = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(5)
TAU = 2 * math.pi


def ph(t, k=1):
    """Fase periódica: da k vueltas en los 12 s."""
    return TAU * k * t / T


# ------------------------------------------------------------------ estrellas que titilan
def make_stars(n, ymax=1.0, seed=1):
    r = np.random.default_rng(seed)
    return dict(x=r.uniform(0, W, n), y=r.uniform(0, H * ymax, n), size=r.choice([1.0, 1.4, 2.0, 2.6], n, p=[.45, .3, .18, .07]),
                k=r.integers(1, 4, n), phase=r.uniform(0, TAU, n), base=r.uniform(0.35, 0.9, n))


def draw_stars(img, st, t, color=(1.0, 0.96, 1.0)):
    """Suma estrellas suaves (pequeñas gaussianas) a una imagen float HxWx3."""
    a = st["base"] * (0.55 + 0.45 * np.sin(ph(t) * st["k"] + st["phase"]))
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            w = np.exp(-(dx * dx + dy * dy) / (2 * (st["size"] * 0.55) ** 2)) * a
            xs = np.clip((st["x"] + dx).astype(int), 0, W - 1)
            ys = np.clip((st["y"] + dy).astype(int), 0, H - 1)
            for c in range(3):
                np.add.at(img[:, :, c], (ys, xs), w * color[c])


def to_rgb(img):
    return (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)


def upscale(low):
    """Imagen de baja resolución (float) → tamaño completo, suave."""
    im = Image.fromarray(to_rgb(low))
    return np.asarray(im.resize((W, H), Image.BICUBIC), dtype=np.float32) / 255


# ------------------------------------------------------------------ 1. Nebulosa
def nebulosa():
    lw, lh = 480, 270
    yy, xx = np.mgrid[0:lh, 0:lw].astype(np.float32)
    blobs = [  # color, centro, radio, frecuencias del recorrido
        ((0.20, 0.80, 1.00), (0.28, 0.38), 0.20, (1, 1), 0.0),
        ((0.38, 0.28, 1.00), (0.60, 0.55), 0.26, (1, 2), 1.3),
        ((0.72, 0.22, 1.00), (0.45, 0.72), 0.20, (2, 1), 2.6),
        ((1.00, 0.35, 0.72), (0.78, 0.30), 0.16, (1, 1), 4.0),
        ((0.15, 0.25, 0.85), (0.18, 0.78), 0.22, (2, 1), 5.1),
    ]
    stars = make_stars(420, seed=11)
    vign = None
    def frame(t):
        nonlocal vign
        img = np.zeros((lh, lw, 3), np.float32)
        img[:] = (0.012, 0.008, 0.03)
        for col, (cx, cy), r, (fx, fy), p0 in blobs:
            x = (cx + 0.10 * math.sin(ph(t, fx) + p0)) * lw
            y = (cy + 0.08 * math.cos(ph(t, fy) + p0 * 1.7)) * lh
            g = np.exp(-(((xx - x) / (r * lw)) ** 2 + ((yy - y) / (r * lw * 0.8)) ** 2))
            pulse = 0.85 + 0.18 * math.sin(ph(t) + p0)
            img += g[..., None] * np.array(col, np.float32) * pulse
        big = upscale(1 - np.exp(-img * 1.4))      # tono con contraste, sin saturar
        if vign is None:
            Y, X = np.mgrid[0:H, 0:W].astype(np.float32)
            vign = (1 - 0.45 * (((X - W / 2) / (W * 0.7)) ** 2 + ((Y - H / 2) / (H * 0.75)) ** 2))[..., None]
        big *= np.clip(vign, 0.35, 1)
        draw_stars(big, stars, t)
        return big
    return frame


# ------------------------------------------------------------------ 2. Montañas rosadas (Serpantium)
def montanas():
    base_path = os.path.join(OUT, ".serpantium-1080.png")
    if not os.path.exists(base_path):
        subprocess.run(["python3", os.path.join(HERE, "..", "serpantium", "fondo.py"), base_path, str(W), str(H)], check=True,
                       stdout=subprocess.DEVNULL)
    base = np.asarray(Image.open(base_path).convert("RGB"), np.float32) / 255
    # máscara de cielo: lo que está arriba de las montañas (más claro y rosado)
    sky = (base.mean(2) > 0.62).astype(np.float32)
    sky = np.asarray(Image.fromarray((sky * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6)), np.float32)[..., None] / 255
    # niebla que se puede repetir de lado: suma de senos con números enteros de vueltas
    fw = W
    xs = np.arange(fw, dtype=np.float32)
    def fog_row(seed):
        r = np.random.default_rng(seed)
        v = np.zeros(fw, np.float32)
        for k in (2, 3, 5, 8, 13):
            v += r.uniform(0.3, 1) * np.sin(TAU * k * xs / fw + r.uniform(0, TAU)) / k ** 0.6
        return (v - v.min()) / (v.max() - v.min())
    bands = [(0.58, 0.05, fog_row(1), 1), (0.72, 0.06, fog_row(2), -1), (0.84, 0.05, fog_row(3), 1)]
    ys = np.arange(H, dtype=np.float32)[:, None]
    stars = make_stars(140, ymax=0.42, seed=21)
    def frame(t):
        img = base.copy()
        for cy, hh, row, d in bands:
            shift = int(d * fw * t / T) % fw        # una vuelta completa en 12 s
            r = np.roll(row, shift)[None, :]
            prof = np.exp(-((ys - cy * H) / (hh * H)) ** 2)
            a = (0.10 + 0.22 * r) * prof
            img = img * (1 - a[..., None]) + np.array((1.0, 0.86, 0.94), np.float32) * a[..., None]
        tw = np.zeros_like(img)
        draw_stars(tw, stars, t)
        img += tw * sky * 0.9
        # estrella fugaz entre los segundos 3 y 3,9
        if 3.0 <= t <= 3.9:
            p = (t - 3.0) / 0.9
            x0, y0 = W * (0.15 + 0.5 * p), H * (0.08 + 0.18 * p)
            for k in range(60):
                q = k / 60
                x, y = int(x0 - q * 160), int(y0 - q * 58)
                if 0 <= x < W and 0 <= y < H:
                    a = (1 - q) * math.sin(math.pi * p) * 0.9
                    img[max(0, y - 1):y + 2, max(0, x - 1):x + 2] += a
        return img
    return frame


# ------------------------------------------------------------------ 3. Aurora
def aurora():
    lw, lh = 640, 360
    yy, xx = np.mgrid[0:lh, 0:lw].astype(np.float32)
    sky = np.zeros((lh, lw, 3), np.float32)
    g = (yy / lh)[..., None]
    sky[:] = (0.02, 0.03, 0.08)
    sky += g * np.array((0.02, 0.10, 0.16), np.float32)
    # silueta de montañas (alta resolución)
    X = np.arange(W)
    def ridge(base, amp, seed):
        r = np.random.default_rng(seed)
        v = sum(r.uniform(.3, 1) / k * np.sin(TAU * k * X / W * 0.5 + r.uniform(0, TAU)) for k in (1, 2, 3, 5, 8, 13, 21))
        return (base - amp * v) * H
    m1, m2 = ridge(0.80, 0.06, 3), ridge(0.88, 0.05, 4)
    Yf = np.arange(H)[:, None]
    mask1 = (Yf > m1[None, :]).astype(np.float32)[..., None]
    mask2 = (Yf > m2[None, :]).astype(np.float32)[..., None]
    stars = make_stars(380, ymax=0.75, seed=31)
    def curtain(t, y0, amp, kx, k, col, width, p0):
        top = (y0 + amp * np.sin(TAU * kx * xx / lw + ph(t, k) + p0)
               + amp * 0.5 * np.sin(TAU * (kx * 2 + 1) * xx / lw - ph(t, k) + p0 * 2)) * lh
        d = yy - top
        body = np.where(d > 0, np.exp(-d / (width * lh)), np.exp(-(d / (0.02 * lh)) ** 2))
        rays = (0.55 + 0.25 * np.sin(TAU * 17 * xx / lw + ph(t, 2) + p0) ** 2
                + 0.20 * np.sin(TAU * 41 * xx / lw - ph(t, 1) + p0 * 3) ** 2)
        return body[..., None] * rays[..., None] * np.array(col, np.float32)
    def frame(t):
        img = sky.copy()
        img += curtain(t, 0.26, 0.07, 1, 1, (0.15, 0.95, 0.60), 0.09, 0.0) * 0.85
        img += curtain(t, 0.36, 0.05, 2, 1, (0.25, 0.70, 1.00), 0.06, 2.1) * 0.40
        img += curtain(t, 0.18, 0.05, 1, 2, (0.75, 0.40, 1.00), 0.05, 4.2) * 0.45
        big = upscale(img / (1 + img * 0.6))
        draw_stars(big, stars, t)
        big = big * (1 - mask1) + mask1 * np.array((0.04, 0.05, 0.10), np.float32)
        big = big * (1 - mask2) + mask2 * np.array((0.015, 0.02, 0.05), np.float32)
        return big
    return frame


SCENES = {"nebulosa": nebulosa, "montanas": montanas, "aurora": aurora}


def render(name):
    frame = SCENES[name]()
    path = os.path.join(OUT, name + ".mp4")
    ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                           "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "22", "-tune", "film",
                           "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", path], stdin=subprocess.PIPE)
    first = None
    for i in range(N):
        rgb = to_rgb(frame(i / FPS))
        if first is None:
            first = rgb
        ff.stdin.write(rgb.tobytes())
    ff.stdin.close()
    ff.wait()
    Image.fromarray(first).save(os.path.join(OUT, name + ".jpg"), quality=90)
    os.makedirs(os.path.join(OUT, "thumbs"), exist_ok=True)
    Image.fromarray(first).resize((480, 270), Image.LANCZOS).save(os.path.join(OUT, "thumbs", name + ".jpg"), quality=85)
    print("listo", name, f"{os.path.getsize(path) / 1e6:.1f} MB")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for n in sys.argv[2:] or list(SCENES):
        render(n)
