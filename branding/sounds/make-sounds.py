#!/usr/bin/env python3
"""Genera los sonidos de Quantum Linux desde cero (síntesis, sin muestras de terceros).
Todos usan la misma escala (La mayor pentatónica) para sonar como una familia:
campanas de cristal suaves con un poco de reverberación.

Uso: make-sounds.py CARPETA_SALIDA   → escribe *.oga (Ogg Vorbis, 48 kHz, estéreo)
"""
import os
import subprocess
import sys

import numpy as np

SR = 48000
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def note(n):
    """Frecuencia de una nota MIDI."""
    return 440.0 * 2 ** ((n - 69) / 12)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def bell(freq, dur, bright=1.0, decay=3.0):
    """Campana de cristal: fundamental + parciales inarmónicos que se apagan antes."""
    t = t_(dur)
    partials = [(1.0, 1.0, 1.0), (2.0, 0.45 * bright, 1.8), (2.76, 0.22 * bright, 2.6),
                (4.07, 0.10 * bright, 3.5), (5.4, 0.05 * bright, 4.5)]
    s = np.zeros_like(t)
    for ratio, amp, dk in partials:
        s += amp * np.sin(2 * np.pi * freq * ratio * t + rng.uniform(0, 6.28)) * np.exp(-t * decay * dk)
    attack = np.minimum(1, t / 0.004)
    return s * attack


def soft(freq, dur, decay=8.0):
    """Tono suave casi puro (para toques cortos)."""
    t = t_(dur)
    s = np.sin(2 * np.pi * freq * t) + 0.18 * np.sin(2 * np.pi * freq * 2 * t)
    return s * np.minimum(1, t / 0.003) * np.exp(-t * decay)


def noise_sweep(dur, f0, f1, decay=4.0):
    """Soplo de aire filtrado que barre de f0 a f1 Hz."""
    n = int(SR * dur)
    x = rng.normal(0, 1, n)
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    out = np.zeros(n)
    # filtro pasa-banda que se mueve: se arma por tramos
    seg = 16
    for k in range(seg):
        a, b = k * n // seg, (k + 1) * n // seg
        fc = f0 + (f1 - f0) * (k + 0.5) / seg
        h = np.exp(-((freqs - fc) / (fc * 0.35)) ** 2)
        y = np.fft.irfft(spec * h, n)
        out[a:b] = y[a:b]
    t = t_(dur)
    env = np.sin(np.pi * np.minimum(1, t / dur)) ** 1.5 * np.exp(-t * decay * 0.2)
    return out / (np.abs(out).max() + 1e-9) * env


def place(buf, sig, at, gain=1.0):
    i = int(at * SR)
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i] * gain


def signal_fft_conv(a, b):
    n = len(a) + len(b) - 1
    m = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(a, m) * np.fft.rfft(b, m), m)[:n]


def reverb(x, size=1.2, mix=0.25):
    """Reverberación simple por convolución con ruido que decae (estéreo levemente distinto)."""
    n = int(SR * size)
    t = np.arange(n) / SR
    out = []
    for ch in range(2):
        ir = rng.normal(0, 1, n) * np.exp(-t * 5.5)
        ir[0] = 0
        ir /= np.sqrt((ir ** 2).sum())
        wet = signal_fft_conv(x, ir)[: len(x) + n]
        wet = np.pad(wet, (0, len(x) + n - len(wet)))
        dry = np.concatenate([x, np.zeros(n)])
        out.append(dry * (1 - mix) + wet * mix * 1.4)
    return np.stack(out, 1)


def save(name, x, rev=0.8, mix=0.22, peak=0.6):
    st = reverb(x, rev, mix)
    # recortar silencio final
    env = np.abs(st).max(1)
    last = np.nonzero(env > 1e-4 * env.max())[0][-1]
    st = st[: last + 1]
    fade = min(len(st), int(0.02 * SR))
    st[-fade:] *= np.linspace(1, 0, fade)[:, None]
    st = st / np.abs(st).max() * peak
    raw = (st * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, name + ".oga")], input=raw, check=True)
    print(name, f"{len(st) / SR:.2f} s")


# La mayor pentatónica: A C# E F# B (MIDI)
A4, Cs5, E5, Fs5, A5, B5, Cs6, E6 = 69, 73, 76, 78, 81, 83, 85, 88

# Inicio de sesión: arpegio ascendente que se abre, con un brillo al final
x = np.zeros(int(SR * 3.2))
for i, (n, at) in enumerate([(A4 - 12, 0.0), (E5 - 12, 0.0), (A4, 0.12), (Cs5, 0.26), (E5, 0.40), (A5, 0.56), (Cs6, 0.74)]):
    place(x, bell(note(n), 2.6, bright=0.8 if n < 70 else 1.0, decay=1.6 if i < 2 else 2.2), at, 0.55 if i < 2 else 0.8)
place(x, noise_sweep(1.2, 1500, 7000) * 0.06, 0.5)
save("startup", x, rev=1.6, mix=0.32, peak=0.55)

# Volumen: gota corta y clara
x = np.zeros(int(SR * 0.12)); place(x, soft(note(E6), 0.12, decay=38), 0, 0.9); place(x, soft(note(E6 + 12), 0.08, decay=60), 0, 0.2)
save("volume", x, rev=0.35, mix=0.12, peak=0.45)

# Interruptor encendido / apagado (barra rápida)
x = np.zeros(int(SR * 0.45)); place(x, bell(note(E5), 0.4, decay=9), 0); place(x, bell(note(B5), 0.4, decay=8), 0.07)
save("toggle-on", x, rev=0.5, mix=0.16, peak=0.45)
x = np.zeros(int(SR * 0.45)); place(x, bell(note(B5), 0.4, decay=9), 0); place(x, bell(note(E5), 0.4, decay=8), 0.07)
save("toggle-off", x, rev=0.5, mix=0.16, peak=0.4)

# Clic suave (abrir paneles, botones)
t = t_(0.06)
click = soft(note(Cs6), 0.06, decay=70) * 0.7 + rng.normal(0, 1, len(t)) * np.exp(-t * 180) * 0.08
save("click", click, rev=0.25, mix=0.08, peak=0.35)

# Notificación: dos notas de cristal
x = np.zeros(int(SR * 1.2)); place(x, bell(note(Cs6), 1.1, decay=3.5), 0); place(x, bell(note(E6), 1.1, decay=3.0), 0.11)
save("notification", x, rev=0.9, mix=0.22, peak=0.5)

# Bloquear: aire que baja + nota grave
x = np.zeros(int(SR * 0.9)); place(x, noise_sweep(0.5, 5000, 900) * 0.25, 0); place(x, bell(note(E5 - 12), 0.8, decay=5), 0.18, 0.7)
save("lock", x, rev=0.8, mix=0.25, peak=0.45)

# Desbloquear: aire que sube + acorde brillante
x = np.zeros(int(SR * 1.3))
place(x, noise_sweep(0.45, 900, 6000) * 0.22, 0)
for n, at in [(A4, 0.18), (E5, 0.24), (A5, 0.30), (Cs6, 0.36)]:
    place(x, bell(note(n), 1.0, decay=3.2), at, 0.6)
save("unlock", x, rev=1.0, mix=0.28, peak=0.5)

# Error (contraseña incorrecta): dos toques graves
x = np.zeros(int(SR * 0.45)); place(x, soft(note(A4 - 12), 0.18, decay=18), 0); place(x, soft(note(A4 - 13), 0.2, decay=16), 0.13)
save("error", x, rev=0.3, mix=0.1, peak=0.45)

# Captura de pantalla: obturador suave
t = t_(0.18)
shutter = rng.normal(0, 1, len(t)) * (np.exp(-t * 60) + 0.6 * np.exp(-((t - 0.07) * 70) ** 2)) * 0.5
place(shutter, soft(note(A5), 0.12, decay=40), 0, 0.3)
save("screenshot", shutter, rev=0.3, mix=0.1, peak=0.4)
