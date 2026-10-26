#!/usr/bin/env python3
"""Tercera ronda de logos de Quantum Linux: el átomo, con el estilo de SKLauncher
(degradado celeste → índigo → violeta, trazos redondeados).

Genera atomo-1.svg ... atomo-4.svg en el directorio de salida.
Uso: atom_options.py <directorio-de-salida>
"""
import math
import sys
from pathlib import Path

CX, CY = 128, 128
RX, RY = 104, 38          # órbita
ANGLES = (90, -30, 30)     # tres órbitas a 60° entre sí (una vertical, como el ejemplo)

DEFS = """
    <linearGradient id="q" x1="0.1" y1="0.05" x2="0.9" y2="0.95">
      <stop offset="0" stop-color="#4FD8FF"/>
      <stop offset="0.5" stop-color="#6A5CFF"/>
      <stop offset="1" stop-color="#B14DFF"/>
    </linearGradient>
    <radialGradient id="core" cx="0.35" cy="0.3" r="0.8">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="0.35" stop-color="#8FE6FF"/>
      <stop offset="1" stop-color="#6A5CFF"/>
    </radialGradient>"""


def svg(body, extra=""):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <defs>{DEFS}{extra}
  </defs>
{body}
</svg>
"""


def point_on(angle_deg, t_deg, rx=RX, ry=RY):
    """Punto de la órbita rotada `angle_deg`, en el parámetro `t_deg`."""
    t, a = math.radians(t_deg), math.radians(angle_deg)
    x, y = rx * math.cos(t), ry * math.sin(t)
    return CX + x * math.cos(a) - y * math.sin(a), CY + x * math.sin(a) + y * math.cos(a)


def electron(x, y, r=11):
    return (f'  <circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="#FFFFFF"/>\n'
            f'  <circle cx="{x:.1f}" cy="{y:.1f}" r="{r * 0.5:.1f}" fill="url(#q)"/>')


def ellipse(angle, width, extra=""):
    return (f'<ellipse cx="{CX}" cy="{CY}" rx="{RX}" ry="{RY}" fill="none" stroke="url(#q)" '
            f'stroke-width="{width}" transform="rotate({angle} {CX} {CY})" {extra}/>')


def atomo_1():
    """Clásico: tres órbitas del mismo grosor, núcleo brillante y dos electrones."""
    body = "\n".join("  " + ellipse(a, 12) for a in ANGLES)
    body += f'\n  <circle cx="{CX}" cy="{CY}" r="22" fill="url(#core)"/>'
    body += "\n" + electron(*point_on(90, -55))
    body += "\n" + electron(*point_on(-30, 200))
    return svg(body)


def crescent(angle, thick, thin):
    """Órbita de trazo variable (gruesa de un lado, fina del otro), como el ejemplo."""
    shift = (thick - thin) / 2
    ro, rio = RX + thick / 2, RY + thick / 2
    ri, rii = RX - thick / 2 + shift, RY - thin / 2
    # anillo = elipse exterior menos una interior desplazada → grosor variable
    return (f'<path fill="url(#q)" fill-rule="evenodd" transform="rotate({angle} {CX} {CY})" d="'
            f'M {CX - ro} {CY} a {ro} {rio} 0 1 0 {2 * ro} 0 a {ro} {rio} 0 1 0 {-2 * ro} 0 Z '
            f'M {CX - ri + shift} {CY} a {ri} {rii} 0 1 0 {2 * ri} 0 a {ri} {rii} 0 1 0 {-2 * ri} 0 Z"/>')


def atomo_2():
    """Caligráfico: órbitas de grosor variable, igual que el ejemplo pero en degradado."""
    body = "\n".join("  " + crescent(a, 16, 4) for a in ANGLES)
    body += f'\n  <circle cx="{CX}" cy="{CY}" r="24" fill="url(#core)"/>'
    body += "\n" + electron(*point_on(90, -55), 12)
    body += "\n" + electron(*point_on(-30, 200), 12)
    return svg(body)


def atomo_3():
    """En baldosa: el átomo clásico sobre un cuadrado redondeado oscuro (ícono de app)."""
    inner = atomo_1().split("</defs>", 1)[1].rsplit("</svg>", 1)[0]
    body = f"""  <rect x="8" y="8" width="240" height="240" rx="56" fill="url(#tile)"/>
  <circle cx="128" cy="128" r="96" fill="url(#halo)"/>
  <rect x="8.5" y="8.5" width="239" height="239" rx="55.5" fill="none" stroke="#FFFFFF" stroke-opacity="0.09"/>
  <g transform="translate(30 30) scale(0.766)">{inner}</g>"""
    extra = """
    <radialGradient id="tile" cx="0.5" cy="0.35" r="0.85">
      <stop offset="0" stop-color="#241C4A"/>
      <stop offset="1" stop-color="#07060D"/>
    </radialGradient>
    <radialGradient id="halo" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#6A5CFF" stop-opacity="0.5"/>
      <stop offset="1" stop-color="#6A5CFF" stop-opacity="0"/>
    </radialGradient>"""
    return svg(body, extra)


def atomo_4():
    """Átomo con núcleo cúbico: une el átomo nuevo con el cubo del logo anterior."""
    body = "\n".join("  " + ellipse(a, 10) for a in ANGLES)
    # cubo isométrico pequeño como núcleo
    s = 26
    top = [(CX, CY - s), (CX + s * 0.87, CY - s / 2), (CX, CY), (CX - s * 0.87, CY - s / 2)]
    left = [(CX - s * 0.87, CY - s / 2), (CX, CY), (CX, CY + s), (CX - s * 0.87, CY + s / 2)]
    right = [(CX, CY), (CX + s * 0.87, CY - s / 2), (CX + s * 0.87, CY + s / 2), (CX, CY + s)]
    pts = lambda p: " ".join(f"{x:.1f},{y:.1f}" for x, y in p)
    for face, op in ((top, 1), (left, 0.75), (right, 0.55)):
        body += (f'\n  <polygon points="{pts(face)}" fill="url(#q)" fill-opacity="{op}" '
                 f'stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="2" stroke-linejoin="round"/>')
    body += "\n" + electron(*point_on(90, -55))
    body += "\n" + electron(*point_on(-30, 200))
    return svg(body)


if __name__ == "__main__":
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    for i, fn in enumerate((atomo_1, atomo_2, atomo_3, atomo_4), 1):
        (out / f"atomo-{i}.svg").write_text(fn())
    print("Opciones generadas en", out)
