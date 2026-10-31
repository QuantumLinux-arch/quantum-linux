#!/usr/bin/env python3
"""Quarki final: el Destello (núcleo oscuro, ojos de chispa) con un aro que gira cuando
está despierto o trabajando. Genera quarki.svg, quarki-duerme.svg y quarki-final.png."""
import math, subprocess, importlib.util
spec = importlib.util.spec_from_file_location("q", "quarki.py"); q = importlib.util.module_from_spec(spec)
import sys; sys.argv = ["x"]
src = open("quarki.py").read().split("# ------------------------------------------------------------------ las 6 opciones")[0]
exec(src, q.__dict__)

def ring(angle, half, k=1, op=1.0, width=None, particle=None):
    """Aro inclinado `angle` grados. half=back (mitad de atrás) o front (mitad de adelante).
    particle = posición 0..1 de la partícula que recorre el aro."""
    rx, ry = 92 * k, 24 * k
    sweep = 1 if half == "back" else 0     # atrás = mitad de arriba; adelante = mitad de abajo
    w = width or (3 if half == "back" else 5)
    s = (f'<g transform="rotate({angle} 100 100)"><path d="M{100-rx},100 A{rx},{ry} 0 0 {sweep} {100+rx},100" fill="none" '
         f'stroke="url(#ring)" stroke-width="{w*k}" stroke-linecap="round" opacity="{op}"/>')
    if particle is not None:
        t = particle * 2 * math.pi
        front = math.sin(t) > 0
        if (half == "front") == front:
            px, py = 100 + rx * math.cos(t), 100 + ry * math.sin(t)
            s += f'<circle cx="{px}" cy="{py}" r="{9*k}" fill="#7FE3FF" opacity=".35"/><circle cx="{px}" cy="{py}" r="{4.5*k}" fill="#fff"/>'
    return s + '</g>'

def quarki(state="awake", angle=-14, particle=0.15, face=None):
    sleep = state == "sleep"
    b, r = q.body_destello(sleep, dark=True)
    k = 0.78 if sleep else 1
    op = 0.35 if sleep else 1
    p = None if sleep else particle
    s = ring(angle, "back", k, op, particle=p) + b
    if state == "done":   # ojos felices: chispas más grandes
        u = r / 40
        for side in (-1, 1):
            x = 100 + side * 13 * u
            s += f'<path d="{q.star4(x, 99, 15*u, 10*u, 0.14)}" fill="#9FEFFF" filter="url(#soft)"/><path d="{q.star4(x, 99, 13*u, 9*u, 0.12)}" fill="#fff"/>'
    elif state == "think":   # mira hacia arriba, una chispa más chica
        u = r / 40
        for side, sz in ((-1, 0.8), (1, 1.0)):
            x = 100 + side * 13 * u + 3 * u
            s += f'<path d="{q.star4(x, 94, 11*u*sz, 7.5*u*sz, 0.12)}" fill="#fff"/>'
    else:
        s += q.face_chispas(100, 100, r, sleep)
    s += ring(angle, "front", k, op, particle=p)
    if state == "done":
        s += q.spark(30, 40, 6, "#BFF4FF") + q.spark(172, 52, 5, "#E3B8FF") + q.spark(160, 168, 4)
    return s

def svg(inner, w=200, h=200):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{q.DEFS}{inner}</svg>'

open("quarki.svg", "w").write(svg(quarki()))
open("quarki-duerme.svg", "w").write(svg(quarki("sleep")))

W, H = 1920, 1080
T = lambda x, y, t, sz, c="#fff", w=400, anchor="middle": f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="Inter" font-weight="{w}" font-size="{sz}" fill="{c}">{t}</text>'
sh = [f'<rect width="{W}" height="{H}" fill="#0E0A1C"/>', T(W/2, 84, "Quarki", 56, w=800), T(W/2, 126, "tu asistente en Quantum", 24, "#A9A3D6")]
# grande, despierto, con globo
sh.append(f'<g transform="translate(150,170) scale(2.6)">{quarki()}</g>')
sh.append('<rect x="700" y="300" width="470" height="70" rx="35" fill="#251C47"/>' + T(935, 345, "Hola. ¿En qué te ayudo?", 28, "#E8E4FF", 600))
sh.append('<rect x="700" y="390" width="470" height="70" rx="35" fill="#1C1538" stroke="#3A2F6A" stroke-width="2"/>' + T(735, 435, "abre Firefox", 26, "#8D86BE", anchor="start"))
# estados
cols = [("sleep", "Durmiendo", "en la barra, respira"), ("awake", "Despierto", "el aro gira despacio"),
        ("think", "Pensando", "mira hacia arriba"), ("done", "¡Listo!", "salta y brilla")]
for i, (st, name, sub) in enumerate(cols):
    x = 1240 + (i % 2) * 330; y = 170 + (i // 2) * 330
    sh.append(f'<rect x="{x}" y="{y}" width="310" height="310" rx="30" fill="#17112C" stroke="#2A2150" stroke-width="2"/>')
    sh.append(f'<g transform="translate({x+55},{y+28}) scale(1.0)">{quarki(st)}</g>')
    if st == "sleep":
        sh.append(f'<text x="{x+210}" y="{y+86}" font-family="Inter" font-weight="800" font-size="24" fill="#C5C0FF">z</text><text x="{x+228}" y="{y+64}" font-family="Inter" font-weight="800" font-size="17" fill="#C5C0FF" opacity=".6">z</text>')
    sh.append(T(x + 155, y + 262, name, 26, w=800) + T(x + 155, y + 292, sub, 19, "#A9A3D6"))
# el aro girando mientras trabaja: 4 cuadros
sh.append(T(560, 740, "Trabajando: el aro gira y la partícula da vueltas", 26, "#E8E4FF", 600))
for i, (ang, par) in enumerate(((-14, 0.05), (8, 0.3), (24, 0.55), (-30, 0.8))):
    x = 60 + i * 260
    sh.append(f'<rect x="{x}" y="770" width="240" height="240" rx="26" fill="#17112C" stroke="#2A2150" stroke-width="2"/>')
    sh.append(f'<g transform="translate({x+20},790)">{quarki("awake", ang, par)}</g>')
    if i < 3:
        sh.append(f'<path d="M{x+246},890 l10,0 m-5,-5 l5,5 l-5,5" stroke="#5A5290" stroke-width="2.5" fill="none" stroke-linecap="round"/>')
# en la barra de tareas
sh.append(T(1580, 860, "en la barra de tareas", 22, "#7E77AE"))
bx, by = 1240, 890
sh.append(f'<rect x="{bx}" y="{by}" width="640" height="96" rx="26" fill="#221A3C" stroke="#342A5C" stroke-width="2"/>')
for j, col in enumerate(("#4FD8FF", "#FF8A3D", "#22C58B", "#FFB547", "#6A5CFF")):
    sh.append(f'<rect x="{bx+28+j*76}" y="{by+22}" width="52" height="52" rx="14" fill="{col}" opacity=".85"/>')
sh.append(f'<g transform="translate({bx+478},{by-12}) scale(0.6)">{quarki("sleep")}</g>')
sh.append(f'<text x="{bx+590}" y="{by+34}" font-family="Inter" font-weight="800" font-size="17" fill="#C5C0FF">z</text>')
open("quarki-final.svg", "w").write(svg("".join(sh), W, H))
subprocess.run(["rsvg-convert", "quarki-final.svg", "-o", "quarki-final.png"], check=True)
print("listo")
