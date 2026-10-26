#!/usr/bin/env python3
"""Segunda ronda de logos de Quantum Linux: la Q como protagonista.

Genera q1.svg ... q4.svg en el directorio de salida.
Uso: q_options.py <directorio-de-salida>
"""
import math
import sys
from pathlib import Path

DEFS = """
    <linearGradient id="q" x1="0.1" y1="0.05" x2="0.9" y2="0.95">
      <stop offset="0" stop-color="#4FD8FF"/>
      <stop offset="0.5" stop-color="#6A5CFF"/>
      <stop offset="1" stop-color="#B14DFF"/>
    </linearGradient>
    <linearGradient id="qsoft" x1="0.1" y1="0.05" x2="0.9" y2="0.95">
      <stop offset="0" stop-color="#4FD8FF" stop-opacity="0.32"/>
      <stop offset="1" stop-color="#B14DFF" stop-opacity="0.32"/>
    </linearGradient>
    <linearGradient id="trail" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#B14DFF" stop-opacity="0"/>
      <stop offset="1" stop-color="#B14DFF"/>
    </linearGradient>"""


def svg(body, extra=""):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <defs>{DEFS}{extra}
  </defs>
{body}
</svg>
"""


def polar(cx, cy, r, deg):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def arc(cx, cy, r, a0, a1):
    """Arco SVG de a0 a a1 grados (sentido horario)."""
    x0, y0 = polar(cx, cy, r, a0)
    x1, y1 = polar(cx, cy, r, a1)
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M {x0:.1f} {y0:.1f} A {r} {r} 0 {large} 1 {x1:.1f} {y1:.1f}"


def tail_mask(x0, y0, x1, y1, width):
    """Máscara que recorta el anillo donde lo cruza la cola (efecto de corte)."""
    return f"""
    <mask id="cut" maskUnits="userSpaceOnUse" x="0" y="0" width="256" height="256">
      <rect width="256" height="256" fill="#fff"/>
      <line x1="{x0}" y1="{y0}" x2="{x1}" y2="{y1}" stroke="#000" stroke-width="{width}" stroke-linecap="round"/>
    </mask>"""


def q1():
    """Q pura: anillo grueso, cola que lo corta y un núcleo brillante."""
    cx, cy, r = 122, 122, 80
    tx0, ty0, tx1, ty1 = 150, 150, 214, 214
    body = f"""  <circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="url(#q)" stroke-width="26" mask="url(#cut)"/>
  <line x1="{tx0}" y1="{ty0}" x2="{tx1}" y2="{ty1}" stroke="url(#q)" stroke-width="26" stroke-linecap="round"/>
  <circle cx="{cx}" cy="{cy}" r="16" fill="#FFFFFF"/>"""
    return svg(body, tail_mask(tx0, ty0, tx1, ty1, 52))


def q2():
    """Q facetada: un hexágono isométrico (el cubo de antes) con paneles, que se cierra en Q."""
    cx, cy, R = 122, 122, 92
    v = [polar(cx, cy, R, a) for a in (-90, -30, 30, 90, 150, 210)]
    top, ur, lr, bot, ll, ul = v
    ring = " ".join(f"{x:.1f},{y:.1f}" for x, y in [top, ur, lr, bot, ll, ul])

    def inset(poly, t):
        mx = sum(p[0] for p in poly) / len(poly)
        my = sum(p[1] for p in poly) / len(poly)
        return " ".join(f"{p[0] + (mx - p[0]) * t:.1f},{p[1] + (my - p[1]) * t:.1f}" for p in poly)

    faces = [[top, ur, (cx, cy), ul], [ul, (cx, cy), bot, ll], [(cx, cy), ur, lr, bot]]
    panels = "\n".join(
        f'  <polygon points="{inset(f, 0.3)}" fill="url(#qsoft)" stroke="url(#q)" stroke-width="5" '
        f'stroke-linejoin="round" mask="url(#cut)"/>' for f in faces)
    tx0, ty0 = cx + 22, cy + 22
    tx1, ty1 = 222, 222
    body = f"""  <polygon points="{ring}" fill="none" stroke="url(#q)" stroke-width="18" stroke-linejoin="round" mask="url(#cut)"/>
{panels}
  <line x1="{tx0}" y1="{ty0}" x2="{tx1}" y2="{ty1}" stroke="url(#q)" stroke-width="20" stroke-linecap="round"/>
  <circle cx="{cx}" cy="{cy}" r="12" fill="#FFFFFF"/>"""
    return svg(body, tail_mask(tx0, ty0, tx1, ty1, 42))


def q3():
    """Q órbita: anillo de Q con un átomo adentro; la cola es la estela de un electrón."""
    cx, cy, r = 122, 122, 80
    ex, ey = 210, 210
    ox, oy = polar(cx, cy, 52, -150)
    body = f"""  <circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="url(#q)" stroke-width="22" mask="url(#cut)"/>
  <ellipse cx="{cx}" cy="{cy}" rx="52" ry="20" fill="none" stroke="url(#q)" stroke-width="6"
           transform="rotate(-30 {cx} {cy})"/>
  <ellipse cx="{cx}" cy="{cy}" rx="52" ry="20" fill="none" stroke="url(#q)" stroke-width="6" opacity="0.6"
           transform="rotate(30 {cx} {cy})"/>
  <line x1="150" y1="150" x2="{ex - 10}" y2="{ey - 10}" stroke="url(#trail)" stroke-width="20" stroke-linecap="round"/>
  <circle cx="{ex}" cy="{ey}" r="17" fill="#FFFFFF"/>
  <circle cx="{ex}" cy="{ey}" r="8" fill="#B14DFF"/>
  <circle cx="{cx}" cy="{cy}" r="12" fill="#FFFFFF"/>"""
    return svg(body, tail_mask(150, 150, ex, ey, 40))


def q4():
    """Q de paneles: el anillo partido en segmentos (como los paneles de SKLauncher)."""
    cx, cy, r = 122, 122, 80
    # Segmentos con huecos; el hueco de abajo a la derecha deja salir la cola.
    # Con extremos redondeados cada hueco necesita ~20° extra para notarse.
    segs = [(74, 166), (206, 298), (338, 390)]
    shades = [0.75, 1.0, 0.88]
    arcs = "\n".join(
        f'  <path d="{arc(cx, cy, r, a0, a1)}" fill="none" stroke="url(#q)" stroke-width="26" '
        f'stroke-linecap="round" opacity="{s}"/>' for (a0, a1), s in zip(segs, shades))
    d = 18
    diamond = f"{cx},{cy - d} {cx + d},{cy} {cx},{cy + d} {cx - d},{cy}"
    body = f"""{arcs}
  <line x1="168" y1="168" x2="216" y2="216" stroke="url(#q)" stroke-width="26" stroke-linecap="round"/>
  <polygon points="{diamond}" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="6" stroke-linejoin="round"/>"""
    return svg(body)


if __name__ == "__main__":
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    for i, fn in enumerate((q1, q2, q3, q4), 1):
        (out / f"q{i}.svg").write_text(fn())
    print("Opciones generadas en", out)
