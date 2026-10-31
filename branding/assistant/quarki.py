#!/usr/bin/env python3
"""Quarki, la mascota y asistente de Quantum: estrella de luz con núcleo oscuro, ojos de
chispa y un aro que gira. Diseño final elegido en branding/mascota-opciones/quarki-final.png.

Genera las capas que anima Quantum Shell (todas en un lienzo de 200x200, centro 100,100):
  glow, rays, body, ring-back (mitad de atrás del aro), ring-front, eyes-open, eyes-closed,
  eyes-happy, eyes-think   → packages/quantum-shell/files/quantum/assets/quarki/*.svg
y el ícono quarki.svg (completo, despierto) para el menú de apps.
"""
import os
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "../../packages/quantum-shell/files/quantum/assets/quarki")

DEFS = '''<defs>
 <radialGradient id="glow"><stop offset="0" stop-color="#7FE3FF" stop-opacity=".5"/><stop offset=".55" stop-color="#6A5CFF" stop-opacity=".16"/><stop offset="1" stop-color="#6A5CFF" stop-opacity="0"/></radialGradient>
 <radialGradient id="star" cx=".5" cy=".5" r=".55"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".22" stop-color="#C9F6FF"/><stop offset=".55" stop-color="#4FD8FF"/><stop offset=".85" stop-color="#6A5CFF"/><stop offset="1" stop-color="#B14DFF"/></radialGradient>
 <radialGradient id="dark" cx=".4" cy=".35" r=".75"><stop offset="0" stop-color="#4A3AB8"/><stop offset=".7" stop-color="#261A6E"/><stop offset="1" stop-color="#1A1050"/></radialGradient>
 <linearGradient id="ray" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0"/><stop offset=".5" stop-color="#FFFFFF"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
 <linearGradient id="ring" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#4FD8FF" stop-opacity=".2"/><stop offset=".5" stop-color="#B14DFF" stop-opacity=".9"/><stop offset="1" stop-color="#4FD8FF" stop-opacity=".2"/></linearGradient>
 <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.2"/></filter>
</defs>'''


def star4(cx, cy, rv, rh, w=0.16):
    """Estrella de 4 puntas de lados cóncavos (rv = punta vertical, rh = horizontal)."""
    a, b = rv * w * 2.2, rh * w * 2.2
    return (f'M{cx},{cy-rv} C{cx+a*0.35},{cy-b} {cx+a},{cy-b*0.35} {cx+rh},{cy} '
            f'C{cx+a},{cy+b*0.35} {cx+a*0.35},{cy+b} {cx},{cy+rv} '
            f'C{cx-a*0.35},{cy+b} {cx-a},{cy+b*0.35} {cx-rh},{cy} '
            f'C{cx-a},{cy-b*0.35} {cx-a*0.35},{cy-b} {cx},{cy-rv} Z')


def glow():
    return '<circle cx="100" cy="100" r="92" fill="url(#glow)"/>'


def rays():
    s = '<rect x="98" y="6" width="4" height="188" rx="2" fill="url(#ray)"/>'
    s += '<rect x="98" y="20" width="4" height="160" rx="2" fill="url(#ray)" transform="rotate(90 100 100)"/>'
    for a in (45, -45):
        s += f'<rect x="98.8" y="44" width="2.4" height="112" fill="url(#ray)" opacity=".6" transform="rotate({a} 100 100)"/>'
    return s


def body():
    return (f'<path d="{star4(100, 100, 62, 56, 0.2)}" fill="url(#star)"/>'
            '<circle cx="100" cy="100" r="40" fill="url(#dark)"/>'
            '<circle cx="100" cy="100" r="40" fill="none" stroke="#9FEFFF" stroke-width="2.5"/>')


def ring(half):
    # atrás = mitad de arriba (pasa detrás de la cabeza); adelante = mitad de abajo
    sweep, w = (1, 3) if half == "back" else (0, 5)
    return (f'<path d="M8,100 A92,24 0 0 {sweep} 192,100" fill="none" stroke="url(#ring)" '
            f'stroke-width="{w}" stroke-linecap="round"/>')


def eyes(kind):
    s = ""
    for side in (-1, 1):
        x = 100 + side * 13
        if kind == "closed":
            s += f'<path d="M{x-5},101 L{x+5},101" stroke="#9FEFFF" stroke-width="2.6" stroke-linecap="round" opacity=".8"/>'
        elif kind == "happy":
            s += f'<path d="{star4(x, 99, 15, 10, 0.14)}" fill="#9FEFFF" filter="url(#soft)"/><path d="{star4(x, 99, 13, 9, 0.12)}" fill="#fff"/>'
        elif kind == "think":   # mira hacia arriba, un ojo más chico
            k = 0.8 if side < 0 else 1.0
            s += f'<path d="{star4(x+3, 93, 11*k, 7.5*k, 0.12)}" fill="#fff"/>'
        else:
            s += f'<path d="{star4(x, 99, 13, 9, 0.14)}" fill="#9FEFFF" filter="url(#soft)"/><path d="{star4(x, 99, 11, 7.5, 0.12)}" fill="#fff"/>'
    return s


def svg(inner):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="200" height="200">{DEFS}{inner}</svg>\n'


def main():
    os.makedirs(OUT, exist_ok=True)
    layers = {"glow": glow(), "rays": rays(), "body": body(), "ring-back": ring("back"), "ring-front": ring("front"),
              "eyes-open": eyes("open"), "eyes-closed": eyes("closed"), "eyes-happy": eyes("happy"), "eyes-think": eyes("think")}
    for name, inner in layers.items():
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(svg(inner))
    # ícono completo: aro inclinado como en el diseño, con su partícula
    tilt = '<g transform="rotate(-14 100 100)">{}</g>'
    icon = (glow() + rays() + tilt.format(ring("back")) + body() + eyes("open") + tilt.format(ring("front"))
            + '<g transform="rotate(-14 100 100)"><circle cx="176" cy="113" r="9" fill="#7FE3FF" opacity=".35"/>'
              '<circle cx="176" cy="113" r="4.5" fill="#fff"/></g>')
    with open(os.path.join(OUT, "quarki.svg"), "w") as f:
        f.write(svg(icon))
    print("listo", OUT)


if __name__ == "__main__":
    main()
