#!/usr/bin/env python3
"""Opciones de logo para Quantum Linux (estilo cubo isométrico, como SKLauncher).

Genera opcion-a.svg ... opcion-d.svg en el directorio de salida.
Uso: logo_options.py <directorio-de-salida>
"""
import math
import sys
from pathlib import Path

C = (128.0, 128.0)   # centro del hexágono
R = 92.0             # radio del hexágono isométrico

GRADIENT = """
    <linearGradient id="q" x1="0.15" y1="0.05" x2="0.85" y2="0.95">
      <stop offset="0" stop-color="#4FD8FF"/>
      <stop offset="0.5" stop-color="#6A5CFF"/>
      <stop offset="1" stop-color="#B14DFF"/>
    </linearGradient>
    <linearGradient id="qsoft" x1="0.15" y1="0.05" x2="0.85" y2="0.95">
      <stop offset="0" stop-color="#4FD8FF" stop-opacity="0.35"/>
      <stop offset="1" stop-color="#B14DFF" stop-opacity="0.35"/>
    </linearGradient>"""


def vertex(angle_deg, r=R, c=C):
    a = math.radians(angle_deg)
    return (c[0] + r * math.cos(a), c[1] + r * math.sin(a))


# Vértices del hexágono (arriba, arriba-der, abajo-der, abajo, abajo-izq, arriba-izq)
TOP, UR, LR, BOT, LL, UL = (vertex(a) for a in (-90, -30, 30, 90, 150, 210))
CEN = C
FACES = {
    "top": [TOP, UR, CEN, UL],
    "left": [UL, CEN, BOT, LL],
    "right": [CEN, UR, LR, BOT],
}


def pts(points):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in points)


def lerp(p, q, t):
    return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)


def inset(poly, t):
    """Encoge un polígono hacia su centroide (t=0 igual, t=1 un punto)."""
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    return [lerp(p, (cx, cy), t) for p in poly]


def centroid(poly):
    return (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))


def svg(body, extra_defs=""):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <defs>{GRADIENT}{extra_defs}
  </defs>
{body}
</svg>
"""


def option_a():
    """Cubo de paneles: el más cercano a SKLauncher, con un núcleo en cada cara."""
    parts = [f'  <polygon points="{pts([TOP, UR, LR, BOT, LL, UL])}" fill="none" stroke="url(#q)" '
             f'stroke-width="12" stroke-linejoin="round"/>',
             f'  <polyline points="{pts([UL, CEN, UR])}" fill="none" stroke="url(#q)" stroke-width="12" stroke-linejoin="round"/>',
             f'  <line x1="{CEN[0]}" y1="{CEN[1]}" x2="{BOT[0]}" y2="{BOT[1]:.1f}" stroke="url(#q)" stroke-width="12" stroke-linecap="round"/>']
    for face in FACES.values():
        panel = inset(face, 0.32)
        parts.append(f'  <polygon points="{pts(panel)}" fill="url(#qsoft)" stroke="url(#q)" '
                     f'stroke-width="5" stroke-linejoin="round"/>')
        core = inset(face, 0.8)
        parts.append(f'  <polygon points="{pts(core)}" fill="url(#q)" stroke="url(#q)" stroke-width="3" stroke-linejoin="round"/>')
    return svg("\n".join(parts))


def option_b():
    """Q isométrica: el contorno del cubo se abre abajo a la derecha y sale la cola de la Q."""
    gap_start = lerp(UR, LR, 0.55)
    gap_end = lerp(LR, BOT, 0.45)
    outline = [gap_end, BOT, LL, UL, TOP, UR, gap_start]
    tail_from = lerp(CEN, LR, 0.35)
    tail_to = vertex(30, R + 26)
    body = f"""  <polyline points="{pts(outline)}" fill="none" stroke="url(#q)" stroke-width="16"
            stroke-linejoin="round" stroke-linecap="round"/>
  <polyline points="{pts([UL, CEN, UR])}" fill="none" stroke="url(#q)" stroke-width="10" stroke-linejoin="round" stroke-linecap="round" opacity="0.85"/>
  <line x1="{CEN[0]}" y1="{CEN[1]}" x2="{BOT[0]}" y2="{BOT[1] - 26:.1f}" stroke="url(#q)" stroke-width="10" stroke-linecap="round" opacity="0.85"/>
  <line x1="{tail_from[0]:.1f}" y1="{tail_from[1]:.1f}" x2="{tail_to[0]:.1f}" y2="{tail_to[1]:.1f}"
        stroke="url(#q)" stroke-width="16" stroke-linecap="round"/>
  <circle cx="{CEN[0]}" cy="{CEN[1]}" r="11" fill="#FFFFFF"/>"""
    return svg(body)


def option_c():
    """Cubo sólido con una órbita: el cubo como átomo."""
    shades = {"top": 0.95, "left": 0.7, "right": 0.5}
    parts = []
    for name, face in FACES.items():
        parts.append(f'  <polygon points="{pts(inset(face, 0.06))}" fill="url(#q)" fill-opacity="{shades[name]}" '
                     f'stroke="url(#q)" stroke-width="6" stroke-linejoin="round"/>')
    # La órbita va en dos mitades: la de atrás antes del cubo y la de adelante después.
    ellipse = ('<ellipse cx="128" cy="128" rx="118" ry="38" fill="none" stroke="#FFFFFF" '
               'stroke-width="7" stroke-opacity="{op}"/>')
    back = (f'  <g transform="rotate(-24 128 128)" clip-path="url(#backhalf)">'
            f'{ellipse.format(op=0.45)}</g>')
    front = (f'  <g transform="rotate(-24 128 128)" clip-path="url(#fronthalf)">'
             f'{ellipse.format(op=0.95)}</g>')
    parts.insert(0, back)
    parts.append(front)
    ex, ey = 128 + 118 * math.cos(math.radians(-24)), 128 + 118 * math.sin(math.radians(-24))
    parts.append(f'  <circle cx="{ex:.1f}" cy="{ey:.1f}" r="12" fill="#FFFFFF"/>')
    parts.append(f'  <circle cx="{ex:.1f}" cy="{ey:.1f}" r="6" fill="url(#q)"/>')
    clips = """
    <clipPath id="backhalf"><rect x="-20" y="40" width="296" height="88"/></clipPath>
    <clipPath id="fronthalf"><rect x="-20" y="128" width="296" height="90"/></clipPath>"""
    return svg("\n".join(parts), clips)


def option_d():
    """Qubit: cada cara dividida en 2x2 celdas; una celda brilla (un bit encendido)."""
    parts = [f'  <polygon points="{pts([TOP, UR, LR, BOT, LL, UL])}" fill="none" stroke="url(#q)" '
             f'stroke-width="10" stroke-linejoin="round"/>']
    lit = ("top", 1, 0)
    for name, (a, b, c, d) in FACES.items():
        for i in range(2):
            for j in range(2):
                u0, u1, v0, v1 = i / 2, (i + 1) / 2, j / 2, (j + 1) / 2

                def at(u, v):
                    # interpolación bilineal dentro de la cara a-b-c-d
                    p = lerp(a, b, u)
                    q = lerp(d, c, u)
                    return lerp(p, q, v)
                cell = inset([at(u0, v0), at(u1, v0), at(u1, v1), at(u0, v1)], 0.22)
                on = (name, i, j) == lit
                fill = "#FFFFFF" if on else "url(#qsoft)"
                parts.append(f'  <polygon points="{pts(cell)}" fill="{fill}" stroke="{fill if on else "url(#q)"}" '
                             f'stroke-width="5" stroke-linejoin="round"/>')
    return svg("\n".join(parts))


if __name__ == "__main__":
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    for key, fn in zip("abcd", (option_a, option_b, option_c, option_d)):
        (out / f"opcion-{key}.svg").write_text(fn())
    print("Opciones generadas en", out)
