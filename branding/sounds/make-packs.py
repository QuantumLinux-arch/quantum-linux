#!/usr/bin/env python3
"""Paquetes de sonidos de Quantum Linux, hechos desde cero (síntesis, sin muestras de nadie).

7 estilos × 10 sonidos del sistema:
  startup, lock, unlock, notification, volume, toggle-on, toggle-off, click, error, screenshot

Uso: make-packs.py CARPETA   → CARPETA/<estilo>/<sonido>.oga  y  CARPETA/muestra-<estilo>.ogg
"""
import os
import subprocess
import sys

import numpy as np

SR = 48000
OUT = sys.argv[1] if len(sys.argv) > 1 else "packs"
rng = np.random.default_rng(11)


# ------------------------------------------------------------------ piezas básicas
def t_(d):
    return np.arange(int(SR * d)) / SR


def hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env(d, a=0.005, decay=4.0, hold=0.0):
    t = t_(d)
    e = np.minimum(1, t / max(a, 1e-4))
    return e * np.exp(-np.maximum(0, t - hold) * decay)


def fade(x, ms=8):
    n = min(len(x), int(SR * ms / 1000))
    if n:
        x[-n:] *= np.linspace(1, 0, n)
    return x


def lowpass_slow(x, fc):
    """Filtro pasa-bajos de un polo, aplicado dos veces (suave y barato)."""
    a = np.exp(-2 * np.pi * fc / SR)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        for i in range(0, len(x), 1):
            acc = (1 - a) * x[i] + a * acc
            y[i] = acc
        x = y
    return x


def lowpass_fast(x, fc):
    """Pasa-bajos por FFT (para señales largas)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1 / np.sqrt(1 + (f / fc) ** 4)
    return np.fft.irfft(spec, len(x))


def reverb(x, size=1.6, mix=0.3, bright=6000):
    """Reverberación por convolución con un eco de ruido que se apaga (estéreo)."""
    n = int(SR * size)
    t = np.arange(n) / SR
    out = []
    for ch in range(2):
        ir = rng.normal(0, 1, n) * np.exp(-t * 6.0 / size)
        ir = lowpass_fast(ir, bright)
        ir[: int(SR * 0.012)] *= np.linspace(0, 1, int(SR * 0.012))
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        m = len(x) + n
        L = 1 << (m - 1).bit_length()
        wet = np.fft.irfft(np.fft.rfft(x, L) * np.fft.rfft(ir, L), L)[:m]   # convolución por FFT (rápida)
        dry = np.concatenate([x, np.zeros(n)])
        out.append(dry * (1 - mix) + wet * mix * 1.4)
    return np.stack(out, 1)


def delay(x, ms=280, fb=0.38, n=5):
    d = int(SR * ms / 1000)
    y = np.concatenate([x, np.zeros(d * n)])
    for k in range(1, n + 1):
        y[d * k: d * k + len(x)] += x * fb ** k
    return y


def stereo(x, width=0.0):
    if x.ndim == 2:
        return x
    if width <= 0:
        return np.stack([x, x], 1)
    d = int(SR * 0.008 * width)
    r = np.concatenate([np.zeros(d), x])[: len(x)]
    return np.stack([x, x * (1 - width * 0.3) + r * width * 0.3], 1)


def seq(parts):
    """[(segundos, señal), …] → mezcla con cada señal empezando en su segundo."""
    end = max(int(SR * s) + len(x) for s, x in parts)
    out = np.zeros(end)
    for s, x in parts:
        i = int(SR * s)
        out[i: i + len(x)] += x
    return out


def noise(d):
    return rng.normal(0, 1, int(SR * d))


# ------------------------------------------------------------------ instrumentos
def glass(f, d=1.6, bright=1.0):
    t = t_(d)
    s = np.zeros_like(t)
    for r, a, k in [(1, 1, 1), (2.76, 0.5 * bright, 2.2), (5.4, 0.28 * bright, 3.4), (8.93, 0.14 * bright, 5), (13.3, 0.06 * bright, 7)]:
        s += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * 2.4 * k)
    return s * np.minimum(1, t / 0.002)


def kalimba(f, d=1.4):
    t = t_(d)
    s = np.sin(2 * np.pi * f * t) * np.exp(-t * 3.2)
    s += 0.35 * np.sin(2 * np.pi * f * 5.95 * t) * np.exp(-t * 18)      # brillo metálico corto
    s += 0.12 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 6)
    click = noise(0.006) * np.exp(-np.arange(int(SR * 0.006)) / (SR * 0.0015)) * 0.25
    s[: len(click)] += click
    return s * np.minimum(1, t / 0.0015)


def marimba(f, d=0.9):
    t = t_(d)
    s = np.sin(2 * np.pi * f * t) * np.exp(-t * 5) + 0.3 * np.sin(2 * np.pi * f * 3.99 * t) * np.exp(-t * 22)
    return s * np.minimum(1, t / 0.002)


def pad(freqs, d=2.4, a=0.4, cutoff=2400):
    t = t_(d)
    s = np.zeros_like(t)
    for f in freqs:
        for det in (-0.12, 0.0, 0.11):
            ff = f * 2 ** (det / 12)
            ph = rng.uniform(0, 1)
            s += 2 * ((ff * t + ph) % 1) - 1                               # diente de sierra
    s = lowpass_fast(s / (3 * len(freqs)), cutoff)
    e = np.minimum(1, t / a) * np.minimum(1, (d - t) / 0.6)
    return s * np.clip(e, 0, 1)


def blip(f, d=0.06, decay=60):
    t = t_(d)
    return (np.sin(2 * np.pi * f * t) + 0.1 * np.sin(4 * np.pi * f * t)) * np.minimum(1, t / 0.001) * np.exp(-t * decay)


def bubble(f0, d=0.18, rise=2.2):
    t = t_(d)
    f = f0 * (1 + rise * (t / d) ** 1.5)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.minimum(1, t / 0.003) * np.exp(-t * (6 / d))


def piano(f, d=1.8, vel=1.0):
    t = t_(d)
    s = np.zeros_like(t)
    for k in range(1, 9):
        fk = f * k * np.sqrt(1 + 0.0004 * k * k)                           # cuerdas algo inarmónicas
        s += (1 / k ** 1.3) * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6)) * np.exp(-t * (1.6 + 0.9 * k))
    ham = lowpass_fast(noise(0.02), 3000) * np.exp(-np.arange(int(SR * 0.02)) / (SR * 0.004)) * 0.15
    s[: len(ham)] += ham
    return s * np.minimum(1, t / 0.002) * vel


def saw_lead(f, d=0.4, cutoff=3000, decay=3.0):
    t = t_(d)
    s = sum(2 * ((f * 2 ** (det / 12) * t + p) % 1) - 1 for det, p in ((-0.08, 0.1), (0.08, 0.6))) / 2
    return lowpass_fast(s, cutoff) * np.minimum(1, t / 0.004) * np.exp(-t * decay)


def snare(d=0.25):
    t = t_(d)
    return (lowpass_fast(noise(d), 6000) * 0.6 + np.sin(2 * np.pi * 190 * t) * 0.5) * np.exp(-t * 18)


# ------------------------------------------------------------------ estilos
def pack_cristal():
    n = hz
    return {
        "startup": reverb(seq([(0.0, glass(n(76), 2.4)), (0.16, glass(n(81), 2.2)), (0.32, glass(n(85), 2.1)), (0.48, glass(n(88), 2.4)), (0.7, glass(n(93), 2.2) * 0.6)]) * 0.5, 2.4, 0.45),
        "lock": reverb(seq([(0, glass(n(88), 1.2)), (0.14, glass(n(81), 1.4))]) * 0.5, 1.6, 0.4),
        "unlock": reverb(seq([(0, glass(n(81), 1.2)), (0.12, glass(n(88), 1.2)), (0.24, glass(n(93), 1.5))]) * 0.5, 1.6, 0.4),
        "notification": reverb(seq([(0, glass(n(88), 1.4)), (0.11, glass(n(93), 1.6))]) * 0.5, 1.6, 0.35),
        "volume": reverb(glass(n(93), 0.25, 0.6) * 0.35, 0.5, 0.2),
        "toggle-on": reverb(seq([(0, glass(n(85), 0.5)), (0.07, glass(n(92), 0.6))]) * 0.45, 0.9, 0.3),
        "toggle-off": reverb(seq([(0, glass(n(92), 0.5)), (0.07, glass(n(85), 0.6))]) * 0.45, 0.9, 0.3),
        "click": stereo(glass(n(100), 0.08, 0.5) * 0.3),
        "error": reverb(seq([(0, glass(n(70), 0.9, 1.4)), (0.0, glass(n(71), 0.9, 1.4)), (0.18, glass(n(65), 1.0, 1.4))]) * 0.4, 1.0, 0.3),
        "screenshot": reverb(seq([(0, noise(0.04) * np.exp(-np.arange(int(SR * 0.04)) / 300) * 0.3), (0.02, glass(n(96), 0.35) * 0.5)]), 0.6, 0.25),
    }


def pack_zen():
    n = hz          # pentatónica menor de La, registro medio
    return {
        "startup": reverb(seq([(0, kalimba(n(57), 2.2)), (0.22, kalimba(n(60), 2.0)), (0.44, kalimba(n(64), 2.0)), (0.66, kalimba(n(67), 2.0)), (0.95, kalimba(n(69), 2.4)), (0.95, kalimba(n(57), 2.4) * 0.5)]) * 0.55, 2.2, 0.35, 4000),
        "lock": reverb(seq([(0, kalimba(n(67), 1.2)), (0.2, kalimba(n(60), 1.4))]) * 0.55, 1.5, 0.3, 4000),
        "unlock": reverb(seq([(0, kalimba(n(60), 1.0)), (0.16, kalimba(n(64), 1.0)), (0.32, kalimba(n(69), 1.4))]) * 0.55, 1.5, 0.3, 4000),
        "notification": reverb(seq([(0, marimba(n(72), 0.9)), (0.13, marimba(n(76), 1.0))]) * 0.55, 1.2, 0.28, 4000),
        "volume": stereo(marimba(n(76), 0.18) * 0.4),
        "toggle-on": reverb(seq([(0, marimba(n(69), 0.4)), (0.08, marimba(n(76), 0.5))]) * 0.5, 0.7, 0.2, 4000),
        "toggle-off": reverb(seq([(0, marimba(n(76), 0.4)), (0.08, marimba(n(69), 0.5))]) * 0.5, 0.7, 0.2, 4000),
        "click": stereo(marimba(n(81), 0.07) * 0.35),
        "error": reverb(seq([(0, marimba(n(52), 0.6)), (0.15, marimba(n(51), 0.8))]) * 0.65, 0.9, 0.25, 3000),
        "screenshot": stereo(seq([(0, lowpass_fast(noise(0.05), 2500) * np.exp(-np.arange(int(SR * 0.05)) / 500) * 0.4), (0.03, marimba(n(84), 0.3) * 0.4)])),
    }


def pack_espacial():
    n = hz
    def sweep(f0, f1, d):
        t = t_(d)
        f = f0 * (f1 / f0) ** (t / d)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.minimum(1, t / 0.05) * np.exp(-t * 2.5)
    return {
        "startup": reverb(delay(seq([(0, pad([n(45), n(52), n(57), n(64)], 2.3, 0.6, 1800) * 0.6), (0.8, glass(n(88), 1.5) * 0.18), (1.1, glass(n(93), 1.5) * 0.14)]), 380, 0.3, 3), 2.0, 0.45, 3500),
        "lock": reverb(delay(sweep(n(76), n(57), 0.6) * 0.4, 260, 0.35, 4), 1.8, 0.45),
        "unlock": reverb(delay(seq([(0, sweep(n(57), n(81), 0.7) * 0.4), (0, pad([n(69), n(76)], 1.0, 0.15) * 0.25)]), 260, 0.35, 4), 1.8, 0.45),
        "notification": reverb(delay(seq([(0, blip(n(81), 0.25, 10)), (0.12, blip(n(88), 0.35, 8))]) * 0.45, 230, 0.4, 4), 1.6, 0.4),
        "volume": stereo(blip(n(88), 0.1, 30) * 0.3),
        "toggle-on": reverb(sweep(n(69), n(81), 0.25) * 0.35, 0.8, 0.35),
        "toggle-off": reverb(sweep(n(81), n(69), 0.25) * 0.35, 0.8, 0.35),
        "click": stereo(blip(n(93), 0.05, 70) * 0.25),
        "error": reverb(delay(seq([(0, saw_lead(n(45), 0.5, 900, 4) * 0.5), (0.0, saw_lead(n(46), 0.5, 900, 4) * 0.5)]), 200, 0.3, 3), 1.2, 0.35),
        "screenshot": reverb(seq([(0, sweep(n(100), n(84), 0.15) * 0.25), (0.0, lowpass_fast(noise(0.08), 5000) * np.exp(-np.arange(int(SR * 0.08)) / 900) * 0.2)]), 0.8, 0.3),
    }


def pack_minimo():
    n = hz
    tick = lambda f, a=0.25: stereo(fade(blip(f, 0.035, 120) * a))
    return {
        "startup": reverb(seq([(0, blip(n(72), 0.3, 12)), (0.12, blip(n(79), 0.4, 10))]) * 0.3, 0.6, 0.15),
        "lock": stereo(seq([(0, blip(n(79), 0.08, 50)), (0.07, blip(n(72), 0.1, 45))]) * 0.25),
        "unlock": stereo(seq([(0, blip(n(72), 0.08, 50)), (0.07, blip(n(79), 0.1, 45))]) * 0.25),
        "notification": stereo(seq([(0, blip(n(84), 0.12, 35)), (0.09, blip(n(84), 0.12, 35))]) * 0.22),
        "volume": tick(n(88), 0.15),
        "toggle-on": tick(n(84), 0.2),
        "toggle-off": tick(n(77), 0.2),
        "click": tick(n(91), 0.12),
        "error": stereo(seq([(0, blip(n(60), 0.12, 30)), (0.1, blip(n(59), 0.15, 30))]) * 0.3),
        "screenshot": stereo(fade(lowpass_fast(noise(0.03), 7000) * np.exp(-np.arange(int(SR * 0.03)) / 200) * 0.15)),
    }


def pack_burbujas():
    n = hz
    pop = lambda f, d=0.12, r=2.2: bubble(f, d, r)
    return {
        "startup": reverb(seq([(0.0, pop(300, 0.2)), (0.15, pop(380, 0.2)), (0.28, pop(460, 0.2)), (0.42, pop(520, 0.22)), (0.6, pop(640, 0.3, 2.8)), (0.62, pop(420, 0.3, 1.5) * 0.6)]) * 0.55, 1.4, 0.3, 5000),
        "lock": reverb(seq([(0, pop(620, 0.18, -0.5)), (0.14, pop(420, 0.22, -0.5))]) * 0.55, 0.9, 0.25),
        "unlock": reverb(seq([(0, pop(380, 0.15)), (0.11, pop(480, 0.15)), (0.22, pop(620, 0.22, 2.6))]) * 0.55, 0.9, 0.25),
        "notification": reverb(seq([(0, pop(520, 0.16)), (0.1, pop(700, 0.2, 2.5))]) * 0.55, 0.8, 0.25),
        "volume": stereo(pop(700, 0.07, 1.5) * 0.4),
        "toggle-on": reverb(pop(480, 0.16, 2.8) * 0.5, 0.5, 0.2),
        "toggle-off": reverb(pop(620, 0.16, -0.6) * 0.5, 0.5, 0.2),
        "click": stereo(pop(900, 0.04, 1.2) * 0.35),
        "error": reverb(seq([(0, pop(260, 0.22, -0.4)), (0.15, pop(200, 0.3, -0.4))]) * 0.65, 0.8, 0.25),
        "screenshot": reverb(seq([(0, pop(800, 0.08, 2)), (0.05, pop(1100, 0.08, 2))]) * 0.45, 0.5, 0.2),
    }


def pack_piano():
    n = hz
    chord = lambda notes, d=2.0, v=0.5: sum(piano(n(k), d, v) for k in notes)
    return {
        "startup": reverb(seq([(0, piano(n(60), 3.0, 0.6)), (0.18, piano(n(64), 2.8, 0.55)), (0.36, piano(n(67), 2.6, 0.55)), (0.6, chord([72, 76, 79], 2.6, 0.42)), (0.6, piano(n(48), 2.6, 0.5))]) * 0.45, 2.2, 0.35, 5000),
        "lock": reverb(seq([(0, piano(n(76), 1.2, 0.5)), (0.16, piano(n(67), 1.5, 0.5))]) * 0.5, 1.4, 0.3),
        "unlock": reverb(seq([(0, piano(n(67), 1.2, 0.5)), (0.13, piano(n(72), 1.2, 0.5)), (0.26, chord([76, 79], 1.6, 0.45))]) * 0.5, 1.4, 0.3),
        "notification": reverb(seq([(0, piano(n(79), 1.3, 0.55)), (0.12, piano(n(84), 1.5, 0.55))]) * 0.5, 1.3, 0.3),
        "volume": stereo(piano(n(84), 0.3, 0.35) * 0.5),
        "toggle-on": reverb(seq([(0, piano(n(72), 0.6, 0.45)), (0.08, piano(n(79), 0.7, 0.45))]) * 0.5, 0.8, 0.22),
        "toggle-off": reverb(seq([(0, piano(n(79), 0.6, 0.45)), (0.08, piano(n(72), 0.7, 0.45))]) * 0.5, 0.8, 0.22),
        "click": stereo(fade(piano(n(91), 0.1, 0.25) * 0.5)),
        "error": reverb(chord([49, 55], 0.9, 0.6) * 0.5, 1.0, 0.25),
        "screenshot": reverb(seq([(0, lowpass_fast(noise(0.04), 4000) * np.exp(-np.arange(int(SR * 0.04)) / 400) * 0.25), (0.02, piano(n(96), 0.4, 0.35) * 0.5)]), 0.7, 0.2),
    }


def pack_synthwave():
    n = hz
    arp = lambda notes, step=0.11, d=0.3, c=2600: seq([(i * step, saw_lead(n(k), d, c, 5)) for i, k in enumerate(notes)])
    gated = lambda x: reverb(x, 0.5, 0.45, 5000)
    return {
        "startup": reverb(seq([(0, delay(seq([(0, arp([57, 64, 69, 72, 76, 81], 0.12, 0.45, 2800) * 0.35), (0, pad([n(45), n(52), n(57), n(64)], 2.6, 0.5, 1600) * 0.45)]), 330, 0.3, 3)), (0.72, snare(0.4) * 0.35)]), 2.0, 0.35, 4500),
        "lock": gated(delay(arp([76, 69, 64], 0.1, 0.3) * 0.35, 220, 0.3, 3)),
        "unlock": gated(delay(arp([64, 69, 76, 81], 0.09, 0.3) * 0.35, 220, 0.3, 3)),
        "notification": gated(delay(arp([81, 88], 0.1, 0.3, 3200) * 0.35, 200, 0.35, 4)),
        "volume": stereo(saw_lead(n(88), 0.08, 3500, 25) * 0.25),
        "toggle-on": gated(arp([76, 83], 0.06, 0.18) * 0.32),
        "toggle-off": gated(arp([83, 76], 0.06, 0.18) * 0.32),
        "click": stereo(fade(saw_lead(n(93), 0.04, 4000, 60) * 0.2)),
        "error": gated(seq([(0, saw_lead(n(45), 0.45, 1200, 3) * 0.45), (0, saw_lead(n(46), 0.45, 1200, 3) * 0.45), (0, snare(0.3) * 0.3)])),
        "screenshot": gated(seq([(0, snare(0.15) * 0.4), (0.02, saw_lead(n(96), 0.12, 5000, 20) * 0.2)])),
    }


PACKS = {"cristal": pack_cristal, "zen": pack_zen, "espacial": pack_espacial, "minimo": pack_minimo,
         "burbujas": pack_burbujas, "piano": pack_piano, "synthwave": pack_synthwave}
ORDER = ["startup", "notification", "toggle-on", "toggle-off", "volume", "volume", "volume", "click", "click",
         "screenshot", "lock", "unlock", "error"]


def finish(x, target=-16.0):
    """Estéreo, recorta silencio final, nivel parejo entre estilos y sin saturar."""
    x = stereo(np.asarray(x, dtype=np.float64))
    mono = np.abs(x).max(1)
    idx = np.nonzero(mono > 1e-4)[0]
    if len(idx):
        x = x[: idx[-1] + int(SR * 0.02)]
    rms = np.sqrt(np.mean(x ** 2)) + 1e-12
    x *= 10 ** (target / 20) / rms
    peak = np.abs(x).max()
    if peak > 0.89:
        x *= 0.89 / peak
    fade(x[:, 0]); fade(x[:, 1])
    return x


def write(path, x):
    raw = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", path], input=raw, check=True)


# nivel por tipo de sonido: el clic y el volumen más bajitos que el inicio
LEVEL = {"startup": -15, "notification": -17, "lock": -18, "unlock": -18, "error": -18, "toggle-on": -20,
         "toggle-off": -20, "screenshot": -21, "volume": -23, "click": -25}

if __name__ == "__main__":
    only = sys.argv[2:] or list(PACKS)
    for name in only:
        sounds = {k: finish(v, LEVEL[k]) for k, v in PACKS[name]().items()}
        d = os.path.join(OUT, name)
        os.makedirs(d, exist_ok=True)
        for k, v in sounds.items():
            write(os.path.join(d, k + ".oga"), v)
        gap = np.zeros((int(SR * 0.45), 2))
        demo = []
        for k in ORDER:
            demo += [sounds[k], gap if k not in ("volume", "click") else np.zeros((int(SR * 0.18), 2))]
        write(os.path.join(OUT, f"muestra-{name}.ogg"), np.concatenate(demo))
        print("listo", name)
