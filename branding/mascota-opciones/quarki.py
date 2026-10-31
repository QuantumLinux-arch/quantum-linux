#!/usr/bin/env python3
"""Rediseño de Quarki (forma de estrella de luz): 6 combinaciones de cuerpo y cara.
Genera quarki-<n>.svg, quarki-<n>-duerme.svg y quarki-opciones.png."""
import math, subprocess

DEFS = '''<defs>
 <radialGradient id="glow"><stop offset="0" stop-color="#7FE3FF" stop-opacity=".5"/><stop offset=".55" stop-color="#6A5CFF" stop-opacity=".16"/><stop offset="1" stop-color="#6A5CFF" stop-opacity="0"/></radialGradient>
 <radialGradient id="star" cx=".5" cy=".5" r=".55"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".22" stop-color="#C9F6FF"/><stop offset=".55" stop-color="#4FD8FF"/><stop offset=".85" stop-color="#6A5CFF"/><stop offset="1" stop-color="#B14DFF"/></radialGradient>
 <linearGradient id="facetL" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#DFFAFF"/><stop offset="1" stop-color="#4FD8FF"/></linearGradient>
 <linearGradient id="facetD" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#6A5CFF"/><stop offset="1" stop-color="#B14DFF"/></linearGradient>
 <radialGradient id="core" cx=".42" cy=".38" r=".7"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".45" stop-color="#BFF4FF"/><stop offset="1" stop-color="#4FD8FF"/></radialGradient>
 <radialGradient id="dark" cx=".4" cy=".35" r=".75"><stop offset="0" stop-color="#4A3AB8"/><stop offset=".7" stop-color="#261A6E"/><stop offset="1" stop-color="#1A1050"/></radialGradient>
 <linearGradient id="ray" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0"/><stop offset=".5" stop-color="#FFFFFF"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
 <linearGradient id="tail" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4FD8FF" stop-opacity=".9"/><stop offset=".5" stop-color="#6A5CFF" stop-opacity=".45"/><stop offset="1" stop-color="#B14DFF" stop-opacity="0"/></linearGradient>
 <linearGradient id="ring" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#4FD8FF" stop-opacity=".2"/><stop offset=".5" stop-color="#B14DFF" stop-opacity=".9"/><stop offset="1" stop-color="#4FD8FF" stop-opacity=".2"/></linearGradient>
 <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.2"/></filter>
</defs>'''
INK = "#150C38"

def star4(cx, cy, rv, rh, w=0.16):
    """Estrella de 4 puntas de lados cóncavos (rv = punta vertical, rh = horizontal)."""
    a, b = rv * w * 2.2, rh * w * 2.2
    return (f'M{cx},{cy-rv} C{cx+a*0.35},{cy-b} {cx+a},{cy-b*0.35} {cx+rh},{cy} '
            f'C{cx+a},{cy+b*0.35} {cx+a*0.35},{cy+b} {cx},{cy+rv} '
            f'C{cx-a*0.35},{cy+b} {cx-a},{cy+b*0.35} {cx-rh},{cy} '
            f'C{cx-a},{cy-b*0.35} {cx-a*0.35},{cy-b} {cx},{cy-rv} Z')

def spark(x, y, r, c="#fff", o=1):
    return f'<path d="{star4(x, y, r, r, 0.12)}" fill="{c}" opacity="{o}"/>'

# ------------------------------------------------------------------ cuerpos (lienzo 200x200, centro 100,100)
def body_pulida(sleep):
    k = 0.78 if sleep else 1
    s = f'<circle cx="100" cy="100" r="{90*k}" fill="url(#glow)"/>'
    if not sleep:
        s += '<ellipse cx="100" cy="100" rx="84" ry="20" fill="none" stroke="url(#ring)" stroke-width="2.4" transform="rotate(-18 100 100)"/>'
    s += f'<path d="{star4(100, 100, 82*k, 70*k)}" fill="url(#star)"/>'
    s += f'<path d="{star4(100, 100, 82*k, 70*k)}" fill="none" stroke="#fff" stroke-opacity=".35" stroke-width="1.2"/>'
    s += f'<circle cx="100" cy="100" r="{36*k}" fill="url(#core)"/>'
    if not sleep:
        s += '<circle cx="176" cy="78" r="4.5" fill="#fff"/><circle cx="176" cy="78" r="9" fill="#7FE3FF" opacity=".35"/>'
    return s, 36 * k

def body_cristal(sleep):
    k = 0.78 if sleep else 1
    s = f'<circle cx="100" cy="100" r="{90*k}" fill="url(#glow)"/>'
    # puntas cortas en diagonal, detrás
    s += f'<path d="{star4(100, 100, 52*k, 52*k)}" fill="url(#facetD)" opacity=".9" transform="rotate(45 100 100)"/>'
    # puntas largas, partidas en mitad clara y mitad oscura (facetas)
    R, H = 84 * k, 70 * k
    pts = [(100, 100 - R), (100 + H, 100), (100, 100 + R), (100 - H, 100)]
    m = 14 * k
    mids = [(100 + m, 100 - m), (100 + m, 100 + m), (100 - m, 100 + m), (100 - m, 100 - m)]
    for i, (px, py) in enumerate(pts):
        a, b = mids[i - 1], mids[i]
        s += f'<path d="M100,100 L{a[0]},{a[1]} L{px},{py} Z" fill="url(#facetL)"/>'
        s += f'<path d="M100,100 L{px},{py} L{b[0]},{b[1]} Z" fill="url(#facetD)"/>'
    s += f'<circle cx="100" cy="100" r="{32*k}" fill="url(#core)"/>'
    s += f'<circle cx="100" cy="100" r="{32*k}" fill="none" stroke="#fff" stroke-opacity=".5" stroke-width="1.5"/>'
    return s, 32 * k

def body_destello(sleep, dark=False):
    k = 0.78 if sleep else 1
    s = f'<circle cx="100" cy="100" r="{92*k}" fill="url(#glow)"/>'
    op = ".45" if sleep else "1"
    s += f'<rect x="{100-2}" y="{100-94*k}" width="4" height="{188*k}" rx="2" fill="url(#ray)" opacity="{op}"/>'
    s += f'<rect x="{100-2}" y="{100-80*k}" width="4" height="{160*k}" rx="2" fill="url(#ray)" opacity="{op}" transform="rotate(90 100 100)"/>'
    s += f'<rect x="{100-1.2}" y="{100-56*k}" width="2.4" height="{112*k}" fill="url(#ray)" opacity="{float(op)*0.6}" transform="rotate(45 100 100)"/>'
    s += f'<rect x="{100-1.2}" y="{100-56*k}" width="2.4" height="{112*k}" fill="url(#ray)" opacity="{float(op)*0.6}" transform="rotate(-45 100 100)"/>'
    s += f'<path d="{star4(100, 100, 62*k, 56*k, 0.2)}" fill="url(#star)"/>'
    s += f'<circle cx="100" cy="100" r="{40*k}" fill="url({"#dark" if dark else "#core"})"/>'
    if dark:
        s += f'<circle cx="100" cy="100" r="{40*k}" fill="none" stroke="#9FEFFF" stroke-width="2.5"/>'
    return s, 40 * k

def body_cometa(sleep):
    k = 0.78 if sleep else 1
    s = f'<circle cx="104" cy="96" r="{88*k}" fill="url(#glow)"/>'
    if not sleep:
        s += '<path d="M90,96 C60,136 36,156 2,196 C46,176 82,156 118,120 Z" fill="url(#tail)"/>'
        s += '<path d="M70,112 C48,124 30,126 8,150 C36,140 58,134 80,128 Z" fill="url(#tail)" opacity=".6"/>'
        s += spark(30, 168, 5, "#BFF4FF") + spark(54, 150, 3.5, "#E3B8FF") + spark(16, 132, 2.5)
    cx, cy = (108, 92) if not sleep else (100, 104)
    s += f'<g transform="rotate({-14 if not sleep else 0} {cx} {cy})"><path d="{star4(cx, cy, 80*k, 66*k)}" fill="url(#star)"/>'
    s += f'<path d="{star4(cx, cy, 80*k, 66*k)}" fill="none" stroke="#fff" stroke-opacity=".35" stroke-width="1.2"/></g>'
    s += f'<circle cx="{cx}" cy="{cy}" r="{36*k}" fill="url(#core)"/>'
    return s, 36 * k, cx, cy

def body_aro(sleep):
    k = 0.78 if sleep else 1
    s = f'<circle cx="100" cy="100" r="{90*k}" fill="url(#glow)"/>'
    # aro detrás (mitad de arriba) y delante (mitad de abajo)
    ring = lambda half: (f'<path d="M{100-88*k},100 A{88*k},{22*k} 0 0 {1 if half=="top" else 0} {100+88*k},100" fill="none" '
                         f'stroke="url(#ring)" stroke-width="{5 if half=="front" else 3}" opacity="{0.5 if sleep else 1}" transform="rotate(-14 100 100)"/>')
    s += ring("top")
    s += f'<path d="{star4(100, 100, 80*k, 64*k)}" fill="url(#star)"/>'
    s += f'<circle cx="100" cy="100" r="{36*k}" fill="url(#core)"/>'
    s += ring("front")
    return s, 36 * k

# ------------------------------------------------------------------ caras (centro cx,cy; r = radio del núcleo)
def face_pildoras(cx, cy, r, sleep, brows=False):
    u = r / 36
    s = ""
    for side in (-1, 1):
        x = cx + side * 12 * u
        if sleep:
            s += f'<path d="M{x-6*u},{cy+2*u} q{6*u},{4*u} {12*u},0" fill="none" stroke="{INK}" stroke-width="{3*u}" stroke-linecap="round"/>'
        else:
            s += f'<rect x="{x-4.6*u}" y="{cy-11*u}" width="{9.2*u}" height="{20*u}" rx="{4.6*u}" fill="{INK}"/>'
            s += f'<rect x="{x-1.6*u}" y="{cy-8*u}" width="{3.2*u}" height="{5*u}" rx="{1.6*u}" fill="#fff" opacity=".9"/>'
        if brows and not sleep:
            s += f'<path d="M{x-7*u*side},{cy-15*u} L{x+6*u*side},{cy-18.5*u}" stroke="{INK}" stroke-width="{3.2*u}" stroke-linecap="round"/>'
    return s

def face_visor(cx, cy, r, sleep):
    u = r / 36
    s = f'<rect x="{cx-27*u}" y="{cy-10*u}" width="{54*u}" height="{20*u}" rx="{10*u}" fill="{INK}" opacity=".92"/>'
    for side in (-1, 1):
        x = cx + side * 11 * u
        if sleep:
            s += f'<rect x="{x-5*u}" y="{cy-0.8*u}" width="{10*u}" height="{1.8*u}" rx="{0.9*u}" fill="#7FE3FF" opacity=".5"/>'
        else:
            s += f'<rect x="{x-6*u}" y="{cy-4*u}" width="{12*u}" height="{8*u}" rx="{4*u}" fill="#7FFFFF" filter="url(#soft)"/>'
            s += f'<rect x="{x-5*u}" y="{cy-3.2*u}" width="{10*u}" height="{6.4*u}" rx="{3.2*u}" fill="#DFFFFF"/>'
    return s

def face_segura(cx, cy, r, sleep):
    u = r / 36
    s = ""
    for side in (-1, 1):
        x = cx + side * 12 * u
        if sleep:
            s += f'<path d="M{x-6*u},{cy+1*u} L{x+6*u},{cy+1*u}" stroke="{INK}" stroke-width="{3*u}" stroke-linecap="round"/>'
            continue
        # párpado de arriba recto e inclinado: mirada tranquila y segura
        t_in, t_out = cy - 2.5 * u, cy - 2.5 * u
        xi, xo = x - side * 6.5 * u, x + side * 6.5 * u
        s += (f'<path d="M{xi},{t_in} L{xo},{t_out} Q{xo},{cy+8*u} {x},{cy+8*u} Q{xi},{cy+8*u} {xi},{t_in} Z" fill="{INK}"/>')
        s += f'<circle cx="{x+2*u}" cy="{cy+1.5*u}" r="{1.8*u}" fill="#fff"/>'
    if not sleep:
        s += f'<path d="M{cx-3*u},{cy+15*u} q{5*u},{3*u} {10*u},-{1.5*u}" fill="none" stroke="{INK}" stroke-width="{2.6*u}" stroke-linecap="round"/>'
    return s

def face_chispas(cx, cy, r, sleep):
    u = r / 40
    s = ""
    for side in (-1, 1):
        x = cx + side * 13 * u
        if sleep:
            s += f'<path d="M{x-5*u},{cy+1*u} L{x+5*u},{cy+1*u}" stroke="#9FEFFF" stroke-width="{2.6*u}" stroke-linecap="round" opacity=".7"/>'
        else:
            s += f'<path d="{star4(x, cy-1*u, 13*u, 9*u, 0.14)}" fill="#9FEFFF" filter="url(#soft)"/>'
            s += f'<path d="{star4(x, cy-1*u, 11*u, 7.5*u, 0.12)}" fill="#fff"/>'
    return s

# ------------------------------------------------------------------ las 6 opciones
def opt1(sl):
    b, r = body_pulida(sl); return b + face_pildoras(100, 100, r, sl)
def opt2(sl):
    b, r = body_pulida(sl); return b + face_visor(100, 100, r, sl)
def opt3(sl):
    b, r = body_cristal(sl); return b + face_segura(100, 100, r, sl)
def opt4(sl):
    b, r = body_destello(sl, dark=True); return b + face_chispas(100, 100, r, sl)
def opt5(sl):
    b, r, cx, cy = body_cometa(sl); return b + face_pildoras(cx, cy, r, sl, brows=True)
def opt6(sl):
    b, r = body_aro(sl); return b + face_segura(100, 100, r, sl)

OPTS = [(opt1, "Estrella pulida", "ojos de píldora, sin boca"),
        (opt2, "Estrella con visor", "visor oscuro con ojos de luz"),
        (opt3, "Cristal", "facetas y mirada tranquila"),
        (opt4, "Destello", "núcleo oscuro, ojos de chispa"),
        (opt5, "Cometa", "con estela y cejas decididas"),
        (opt6, "Con aro", "un anillo como planeta")]

def svg(inner, w=200, h=200):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{DEFS}{inner}</svg>'

def zz(x, y, sc=1):
    return (f'<text x="{x}" y="{y}" font-family="Inter" font-weight="800" font-size="{18*sc}" fill="#C5C0FF">z</text>'
            f'<text x="{x+13*sc}" y="{y-14*sc}" font-family="Inter" font-weight="800" font-size="{13*sc}" fill="#C5C0FF" opacity=".6">z</text>')

W, H = 1920, 1160
sh = [f'<rect width="{W}" height="{H}" fill="#0E0A1C"/>',
      f'<text x="{W/2}" y="86" text-anchor="middle" font-family="Inter" font-weight="800" font-size="50" fill="#fff">Quarki: ¿cuál te gusta más?</text>',
      f'<text x="{W/2}" y="130" text-anchor="middle" font-family="Inter" font-size="23" fill="#A9A3D6">Despierto, y durmiendo en la barra de tareas</text>']
cw, chh = 600, 480
for i, (fn, name, sub) in enumerate(OPTS):
    n = i + 1
    open(f"quarki-{n}.svg", "w").write(svg(fn(False)))
    open(f"quarki-{n}-duerme.svg", "w").write(svg(fn(True)))
    x0 = 40 + (i % 3) * (cw + 20); y0 = 170 + (i // 3) * (chh + 20)
    sh.append(f'<rect x="{x0}" y="{y0}" width="{cw}" height="{chh}" rx="34" fill="#17112C" stroke="#2A2150" stroke-width="2"/>')
    sh.append(f'<text x="{x0+36}" y="{y0+58}" font-family="Inter" font-weight="800" font-size="34" fill="#fff">{n}. {name}</text>')
    sh.append(f'<text x="{x0+36}" y="{y0+94}" font-family="Inter" font-size="21" fill="#A9A3D6">{sub}</text>')
    sh.append(f'<g transform="translate({x0+20},{y0+120}) scale(1.6)">{fn(False)}</g>')
    # barra de tareas a la derecha, con Quarki durmiendo
    bx, by = x0 + 360, y0 + 300
    sh.append(f'<rect x="{bx}" y="{by}" width="210" height="76" rx="20" fill="#221A3C" stroke="#342A5C" stroke-width="2"/>')
    for j, col in enumerate(("#4FD8FF", "#FF8A3D")):
        sh.append(f'<rect x="{bx+18+j*54}" y="{by+19}" width="38" height="38" rx="11" fill="{col}" opacity=".85"/>')
    sh.append(f'<g transform="translate({bx+128},{by-4}) scale(0.42)">{fn(True)}</g>')
    sh.append(zz(bx + 192, by + 18, 0.7))
    sh.append(f'<text x="{bx+105}" y="{by+108}" text-anchor="middle" font-family="Inter" font-size="18" fill="#7E77AE">durmiendo</text>')
    sh.append(f'<g transform="translate({bx+40},{by-196}) scale(0.65)">{fn(True)}</g>' + zz(bx + 150, by - 150, 0.9))
open("quarki-opciones.svg", "w").write(svg("".join(sh), W, H))
subprocess.run(["rsvg-convert", "quarki-opciones.svg", "-o", "quarki-opciones.png"], check=True)
print("listo")
