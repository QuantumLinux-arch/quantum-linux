#!/usr/bin/env python3
"""Genera los SVG derivados de Quantum Linux (logo en variantes, ícono,
logotipo y fondos de pantalla).

La marca base está en src/quantum-mark.svg (cubo con órbita); la paleta vive
aquí para que todo salga coherente.
"""
import math
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
OUT = ROOT / "generated"

PALETTE = {
    "bg_deep": "#07060D",
    "bg": "#0D0B14",
    "surface": "#15121F",
    "text": "#EEEAFB",
    "muted": "#9C95B8",
    "cyan": "#4FD8FF",
    "indigo": "#6A5CFF",
    "violet": "#B14DFF",
    "ink": "#221B45",       # órbita del logo sobre fondos claros
    "light_bg": "#F4F2FB",
}


def mark_parts(orbit=None):
    """(defs, cuerpo) de la marca; `orbit` cambia el color de la órbita."""
    svg = (SRC / "quantum-mark.svg").read_text()
    if orbit:
        svg = svg.replace("#FFFFFF", orbit)
    defs = re.search(r"<defs>(.*?)</defs>", svg, re.S).group(1)
    body = svg.split("</defs>", 1)[1].rsplit("</svg>", 1)[0]
    return defs, body


def write(name, content):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(content)


def mark_variants():
    defs, body = mark_parts(PALETTE["ink"])
    write("quantum-mark-light.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <defs>{defs}</defs>{body}</svg>
""")
    # Versión monocroma (blanca) para el panel y bandejas
    svg = (SRC / "quantum-mark.svg").read_text()
    mono = re.sub(r'url\(#q(soft)?\)', "#FFFFFF", svg)
    write("quantum-mark-symbolic.svg", mono)


def app_icon():
    defs, body = mark_parts()
    write("quantum-icon.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <defs>{defs}
    <radialGradient id="tile" cx="0.5" cy="0.35" r="0.85">
      <stop offset="0" stop-color="#241C4A"/>
      <stop offset="1" stop-color="{PALETTE['bg_deep']}"/>
    </radialGradient>
    <radialGradient id="halo" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="{PALETTE['indigo']}" stop-opacity="0.55"/>
      <stop offset="1" stop-color="{PALETTE['indigo']}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect x="8" y="8" width="240" height="240" rx="56" fill="url(#tile)"/>
  <circle cx="128" cy="128" r="100" fill="url(#halo)"/>
  <rect x="8.5" y="8.5" width="239" height="239" rx="55.5" fill="none" stroke="#FFFFFF" stroke-opacity="0.09"/>
  <g transform="translate(36 36) scale(0.72)">{body}</g>
</svg>
""")


def wordmark(color, sub, name, orbit=None):
    defs, body = mark_parts(orbit)
    write(name, f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 256" width="900" height="256">
  <defs>{defs}</defs>
  <g transform="translate(0 0)">{body}</g>
  <text x="272" y="150" font-family="Inter" font-weight="800" font-size="128" letter-spacing="-4" fill="{color}">Quantum</text>
  <text x="278" y="208" font-family="Inter" font-weight="600" font-size="38" letter-spacing="22" fill="{sub}">LINUX</text>
</svg>
""")


# --------------------------------------------------------------- fondos

def iso_grid(w, h, step, color, opacity):
    """Rejilla isométrica: líneas a ±30° y verticales."""
    lines = []
    t = math.tan(math.radians(30))
    span = w + h
    for k in range(-int(span / step), int(span / step) + 1):
        x0 = k * step
        lines.append(f'<line x1="{x0:.0f}" y1="0" x2="{x0 + h / t:.0f}" y2="{h}"/>')
        lines.append(f'<line x1="{x0:.0f}" y1="0" x2="{x0 - h / t:.0f}" y2="{h}"/>')
    for k in range(0, int(w / (step * t * 2)) + 2):
        x = k * step / t * 0.5 * 2
        lines.append(f'<line x1="{x:.0f}" y1="0" x2="{x:.0f}" y2="{h}"/>')
    return (f'<g stroke="{color}" stroke-opacity="{opacity}" stroke-width="1.4" mask="url(#fade)">'
            + "".join(lines) + "</g>")


def orbits(cx, cy, specs):
    out = []
    for rx, ry, rot, width, op in specs:
        out.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="none" stroke="url(#orb)" '
                   f'stroke-width="{width}" stroke-opacity="{op}" transform="rotate({rot} {cx} {cy})"/>')
    return "\n  ".join(out)


def particles(rng, n, w, h, colors, cx=None, cy=None, spread=None):
    out = []
    for _ in range(n):
        if cx is not None:
            a = rng.uniform(0, 2 * math.pi)
            r = abs(rng.gauss(0, spread))
            x, y = cx + r * math.cos(a), cy + r * math.sin(a) * 0.6
        else:
            x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.choice([1.5, 2, 2, 3, 3, 4, 6])
        op = rng.uniform(0.3, 0.95) * (0.5 if r > 4 else 1)
        out.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" fill="{rng.choice(colors)}" '
                   f'fill-opacity="{op:.2f}" filter="url(#glow)"/>')
    return "\n  ".join(out)


COMMON_DEFS = f"""
    <filter id="blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="240"/></filter>
    <filter id="glow" x="-300%" y="-300%" width="700%" height="700%"><feGaussianBlur stdDeviation="2.5"/></filter>
    <linearGradient id="orb" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{PALETTE['cyan']}"/>
      <stop offset="0.5" stop-color="{PALETTE['indigo']}"/>
      <stop offset="1" stop-color="{PALETTE['violet']}"/>
    </linearGradient>"""


def wallpaper_orbita(w=3840, h=2160):
    """Fondo principal: rejilla isométrica, órbitas grandes y partículas."""
    rng = random.Random(11)
    cx, cy = w * 0.68, h * 0.46
    write("wallpaper-orbita.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">
  <defs>{COMMON_DEFS}
    <radialGradient id="fadeg" cx="0.68" cy="0.46" r="0.6">
      <stop offset="0" stop-color="#fff"/>
      <stop offset="1" stop-color="#000"/>
    </radialGradient>
    <mask id="fade"><rect width="{w}" height="{h}" fill="url(#fadeg)"/></mask>
    <radialGradient id="vig" cx="0.5" cy="0.5" r="0.75">
      <stop offset="0.55" stop-color="#000" stop-opacity="0"/>
      <stop offset="1" stop-color="#000" stop-opacity="0.6"/>
    </radialGradient>
  </defs>
  <rect width="{w}" height="{h}" fill="{PALETTE['bg_deep']}"/>
  <circle cx="{cx:.0f}" cy="{cy:.0f}" r="{h * 0.36:.0f}" fill="{PALETTE['indigo']}" fill-opacity="0.55" filter="url(#blur)"/>
  <circle cx="{w * 0.85:.0f}" cy="{h * 0.15:.0f}" r="{h * 0.3:.0f}" fill="{PALETTE['violet']}" fill-opacity="0.35" filter="url(#blur)"/>
  <circle cx="{w * 0.2:.0f}" cy="{h * 0.9:.0f}" r="{h * 0.35:.0f}" fill="{PALETTE['cyan']}" fill-opacity="0.22" filter="url(#blur)"/>
  {iso_grid(w, h, 120, "#8F86FF", 0.10)}
  {orbits(round(cx), round(cy), [(1300, 330, -22, 3, 0.55), (1050, 260, -22, 2, 0.35), (1550, 420, -22, 1.5, 0.22), (700, 180, 38, 2, 0.28)])}
  <circle cx="{cx + 1300 * math.cos(math.radians(-22)) * 0.0 - 1205:.0f}" cy="{cy + 487:.0f}" r="16" fill="#FFFFFF" filter="url(#glow)"/>
  {particles(rng, 180, w, h, [PALETTE['cyan'], '#FFFFFF', PALETTE['violet']], cx, cy, 900)}
  <rect width="{w}" height="{h}" fill="url(#vig)"/>
</svg>
""")


def wallpaper_nucleo(w=3840, h=2160):
    """Logo centrado sobre un resplandor: ideal para la pantalla de inicio."""
    defs, body = mark_parts()
    rng = random.Random(5)
    write("wallpaper-nucleo.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">
  <defs>{defs}{COMMON_DEFS}
    <radialGradient id="fadeg" cx="0.5" cy="0.5" r="0.45">
      <stop offset="0" stop-color="#fff"/>
      <stop offset="1" stop-color="#000"/>
    </radialGradient>
    <mask id="fade"><rect width="{w}" height="{h}" fill="url(#fadeg)"/></mask>
  </defs>
  <rect width="{w}" height="{h}" fill="{PALETTE['bg_deep']}"/>
  <circle cx="{w / 2:.0f}" cy="{h / 2:.0f}" r="{h * 0.3:.0f}" fill="{PALETTE['indigo']}" fill-opacity="0.45" filter="url(#blur)"/>
  {iso_grid(w, h, 110, "#8F86FF", 0.08)}
  <g transform="translate({w / 2 - 300:.0f} {h / 2 - 300:.0f}) scale(2.34)">{body}</g>
  {particles(rng, 90, w, h, [PALETTE['cyan'], '#FFFFFF', PALETTE['violet']], w / 2, h / 2, 1100)}
</svg>
""")


def wallpaper_aurora(w=3840, h=2160):
    """Variante clara para el modo claro."""
    rng = random.Random(8)
    cx, cy = w * 0.3, h * 0.55
    write("wallpaper-aurora.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">
  <defs>{COMMON_DEFS}
    <radialGradient id="fadeg" cx="0.3" cy="0.55" r="0.65">
      <stop offset="0" stop-color="#fff"/>
      <stop offset="1" stop-color="#000"/>
    </radialGradient>
    <mask id="fade"><rect width="{w}" height="{h}" fill="url(#fadeg)"/></mask>
  </defs>
  <rect width="{w}" height="{h}" fill="{PALETTE['light_bg']}"/>
  <circle cx="{w * 0.25:.0f}" cy="{h * 0.6:.0f}" r="{h * 0.4:.0f}" fill="#BFE9FF" filter="url(#blur)"/>
  <circle cx="{w * 0.8:.0f}" cy="{h * 0.2:.0f}" r="{h * 0.4:.0f}" fill="#E2CCFF" filter="url(#blur)"/>
  <circle cx="{w * 0.55:.0f}" cy="{h * 0.85:.0f}" r="{h * 0.3:.0f}" fill="#CFC9FF" filter="url(#blur)"/>
  {iso_grid(w, h, 120, PALETTE['indigo'], 0.08)}
  {orbits(round(cx), round(cy), [(1400, 360, -18, 3, 0.45), (1100, 280, -18, 2, 0.3), (760, 200, 34, 2, 0.25)])}
  {particles(rng, 90, w, h, [PALETTE['indigo'], PALETTE['violet'], PALETTE['cyan']], cx, cy, 1000)}
</svg>
""")


if __name__ == "__main__":
    mark_variants()
    app_icon()
    wordmark(PALETTE["text"], PALETTE["muted"], "quantum-wordmark-light.svg")   # fondos oscuros
    wordmark(PALETTE["ink"], "#6E6890", "quantum-wordmark-dark.svg", orbit=PALETTE["ink"])  # fondos claros
    wallpaper_orbita()
    wallpaper_nucleo()
    wallpaper_aurora()
    print("SVG generados en", OUT)
