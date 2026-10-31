#!/usr/bin/env python3
"""Opciones de mascota para el asistente de Quantum: cada una despierta y durmiendo.
Genera <id>.svg (despierta), <id>-duerme.svg y opciones.png (las 4 juntas)."""
import subprocess

GRAD = '''<defs>
 <linearGradient id="q" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#4FD8FF"/><stop offset=".5" stop-color="#6A5CFF"/><stop offset="1" stop-color="#B14DFF"/></linearGradient>
 <radialGradient id="body" cx=".38" cy=".32" r=".8"><stop offset="0" stop-color="#9FF0FF"/><stop offset=".35" stop-color="#4FD8FF"/><stop offset=".7" stop-color="#6A5CFF"/><stop offset="1" stop-color="#9B45F0"/></radialGradient>
 <radialGradient id="glow"><stop offset="0" stop-color="#7FE3FF" stop-opacity=".55"/><stop offset=".6" stop-color="#6A5CFF" stop-opacity=".18"/><stop offset="1" stop-color="#6A5CFF" stop-opacity="0"/></radialGradient>
 <linearGradient id="tail" x1="1" y1="0" x2="0" y2="0"><stop offset="0" stop-color="#6A5CFF" stop-opacity=".95"/><stop offset=".6" stop-color="#B14DFF" stop-opacity=".5"/><stop offset="1" stop-color="#B14DFF" stop-opacity="0"/></linearGradient>
 <radialGradient id="star" cx=".45" cy=".4" r=".7"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".3" stop-color="#BFF4FF"/><stop offset=".75" stop-color="#4FD8FF"/><stop offset="1" stop-color="#6A5CFF"/></radialGradient>
 <linearGradient id="cat" x1="0" y1="0" x2=".6" y2="1"><stop offset="0" stop-color="#8FEBFF" stop-opacity=".95"/><stop offset=".5" stop-color="#6A5CFF" stop-opacity=".92"/><stop offset="1" stop-color="#B14DFF" stop-opacity=".9"/></linearGradient>
</defs>'''

def eyes(cx, cy, dx, r=7.5, sleep=False, color="#1B1240"):
    if sleep:
        return "".join(f'<path d="M{x-r},{cy} q{r},{r*0.9} {2*r},0" fill="none" stroke="{color}" stroke-width="3.2" stroke-linecap="round"/>' for x in (cx-dx, cx+dx))
    out = ""
    for x in (cx-dx, cx+dx):
        out += (f'<ellipse cx="{x}" cy="{cy}" rx="{r}" ry="{r*1.25}" fill="{color}"/>'
                f'<circle cx="{x+r*0.35}" cy="{cy-r*0.45}" r="{r*0.38}" fill="#fff"/>'
                f'<circle cx="{x-r*0.3}" cy="{cy+r*0.45}" r="{r*0.16}" fill="#fff" opacity=".8"/>')
    return out

def cheeks(cx, cy, dx, r=6):
    return "".join(f'<ellipse cx="{x}" cy="{cy}" rx="{r}" ry="{r*0.6}" fill="#FF7FC8" opacity=".55"/>' for x in (cx-dx, cx+dx))

def smile(cx, cy, w=8, sleep=False):
    if sleep:
        return f'<ellipse cx="{cx}" cy="{cy+1}" rx="2.6" ry="2" fill="#1B1240" opacity=".7"/>'
    return f'<path d="M{cx-w},{cy} q{w},{w*0.9} {2*w},0" fill="none" stroke="#1B1240" stroke-width="3" stroke-linecap="round"/>'

def zz(x, y):
    return (f'<text x="{x}" y="{y}" font-family="Inter" font-weight="800" font-size="16" fill="#C5C0FF" opacity=".9">z</text>'
            f'<text x="{x+12}" y="{y-14}" font-family="Inter" font-weight="800" font-size="12" fill="#C5C0FF" opacity=".6">z</text>')

# ------------------------------------------------------------------ cada mascota (lienzo 200x200)
def quarki(sleep=False):
    s = '<circle cx="100" cy="104" r="80" fill="url(#glow)"/>'
    if not sleep:   # colita de luz
        s += '<path d="M62,120 C30,130 22,160 2,150 C26,172 52,150 72,136 Z" fill="url(#tail)"/>'
        s += '<circle cx="18" cy="138" r="3" fill="#BFF4FF"/><circle cx="34" cy="160" r="2" fill="#E3B8FF"/>'
    else:
        s += '<path d="M64,140 C44,150 40,160 52,166 C60,160 70,154 80,150 Z" fill="url(#tail)"/>'
    body_ry = 50 if not sleep else 40
    s += f'<ellipse cx="104" cy="{108 if not sleep else 122}" rx="{54 if not sleep else 58}" ry="{body_ry}" fill="url(#body)"/>'
    cy = 104 if not sleep else 122
    s += f'<ellipse cx="86" cy="{cy-28 if not sleep else cy-20}" rx="18" ry="9" fill="#fff" opacity=".45" transform="rotate(-25 86 {cy-28})"/>'
    if not sleep:   # antenita con chispa
        s += '<path d="M112,60 q4,-18 16,-24" fill="none" stroke="#7FE3FF" stroke-width="3" stroke-linecap="round"/><circle cx="130" cy="34" r="6" fill="#fff"/><circle cx="130" cy="34" r="10" fill="#7FE3FF" opacity=".35"/>'
    s += eyes(106, cy - 4, 17, sleep=sleep) + cheeks(106, cy + 12, 30) + smile(106, cy + 13, 7, sleep)
    if sleep: s += zz(150, 82)
    return s

def atomo(sleep=False):
    s = '<circle cx="100" cy="100" r="88" fill="url(#glow)"/>'
    op = ".95" if not sleep else ".35"
    for a, dot in ((0, (180, 100)), (60, None), (-60, None)):
        s += f'<ellipse cx="100" cy="100" rx="86" ry="30" fill="none" stroke="url(#q)" stroke-width="5" opacity="{op}" transform="rotate({a} 100 100)"/>'
    if not sleep:   # electrones = manitos (una saludando)
        s += '<circle cx="186" cy="70" r="9" fill="#fff"/><circle cx="186" cy="70" r="14" fill="#7FE3FF" opacity=".35"/>'
        s += '<circle cx="18" cy="118" r="8" fill="#E3B8FF"/>'
        s += '<circle cx="128" cy="178" r="7" fill="#BFF4FF"/>'
    else:
        s += '<circle cx="182" cy="104" r="6" fill="#fff" opacity=".5"/><circle cx="56" cy="34" r="5" fill="#fff" opacity=".4"/>'
    s += '<circle cx="100" cy="100" r="44" fill="url(#body)"/>'
    s += '<ellipse cx="84" cy="80" rx="13" ry="7" fill="#fff" opacity=".45" transform="rotate(-25 84 80)"/>'
    s += eyes(100, 98, 14, r=6.5, sleep=sleep) + cheeks(100, 112, 25, 5) + smile(100, 112, 6, sleep)
    if sleep: s += zz(140, 56)
    return s

def foton(sleep=False):
    s = '<circle cx="110" cy="100" r="86" fill="url(#glow)"/>'
    if not sleep:   # estela de chispas
        for x, y, r, c in ((40, 140, 7, "#BFF4FF"), (22, 158, 5, "#E3B8FF"), (10, 172, 3, "#7FE3FF"), (56, 160, 3, "#fff")):
            s += f'<path d="M{x},{y-r*1.8} Q{x},{y} {x+r*1.8},{y} Q{x},{y} {x},{y+r*1.8} Q{x},{y} {x-r*1.8},{y} Q{x},{y} {x},{y-r*1.8} Z" fill="{c}"/>'
    k = 1 if not sleep else 0.8
    cx, cy = 110, 100 if not sleep else 116
    R = 78 * k
    # estrella de 4 puntas con lados curvos y centro redondo
    s += (f'<path d="M{cx},{cy-R} C{cx+12},{cy-34} {cx+34},{cy-12} {cx+R},{cy} C{cx+34},{cy+12} {cx+12},{cy+34} {cx},{cy+R} '
          f'C{cx-12},{cy+34} {cx-34},{cy+12} {cx-R},{cy} C{cx-34},{cy-12} {cx-12},{cy-34} {cx},{cy-R} Z" fill="url(#star)"/>')
    s += f'<circle cx="{cx}" cy="{cy}" r="{38*k}" fill="url(#star)"/>'
    if not sleep:
        s += '<path d="M168,40 l3,8 l8,3 l-8,3 l-3,8 l-3,-8 l-8,-3 l8,-3 z" fill="#fff"/>'
    s += eyes(cx, cy - 3, 13, r=6.5, sleep=sleep, color="#1B1240") + cheeks(cx, cy + 12, 23, 5) + smile(cx, cy + 12, 6, sleep)
    if sleep: s += zz(150, 70)
    return s

def gatito(sleep=False):
    s = '<circle cx="100" cy="110" r="86" fill="url(#glow)"/>'
    if not sleep:
        s += '<path d="M140,160 C182,160 186,118 166,100 C178,124 170,146 136,146 Z" fill="url(#cat)"/>'   # cola
        s += '<ellipse cx="104" cy="148" rx="46" ry="34" fill="url(#cat)"/>'                              # cuerpo
        s += '<path d="M56,92 L60,40 L86,66 Z" fill="url(#cat)"/><path d="M144,92 L140,40 L114,66 Z" fill="url(#cat)"/>'
        s += '<path d="M63,74 L65,52 L78,66 Z" fill="#FF9AD5" opacity=".7"/><path d="M137,74 L135,52 L122,66 Z" fill="#FF9AD5" opacity=".7"/>'
        s += '<ellipse cx="100" cy="92" rx="52" ry="42" fill="url(#cat)"/>'
        s += '<ellipse cx="80" cy="66" rx="14" ry="7" fill="#fff" opacity=".4" transform="rotate(-20 80 66)"/>'
        cy = 90
        s += eyes(100, cy, 20, r=7.5) + cheeks(100, cy + 16, 34, 6)
        s += f'<path d="M96,{cy+10} l4,4 l4,-4 z" fill="#FF7FC8"/><path d="M92,{cy+18} q4,4 8,0 q4,4 8,0" fill="none" stroke="#1B1240" stroke-width="2.6" stroke-linecap="round"/>'
        for side in (-1, 1):
            for dy in (-3, 5):
                s += f'<line x1="{100+side*36}" y1="{cy+12+dy}" x2="{100+side*62}" y2="{cy+8+dy*1.6}" stroke="#E8E4FF" stroke-width="1.8" opacity=".7"/>'
        s += '<circle cx="62" cy="34" r="3" fill="#BFF4FF"/><circle cx="150" cy="28" r="2.4" fill="#E3B8FF"/>'
    else:   # enrollado
        s += '<ellipse cx="100" cy="134" rx="66" ry="40" fill="url(#cat)"/>'
        s += '<path d="M44,140 C40,170 120,178 158,156 C130,166 70,166 56,140 Z" fill="#B14DFF" opacity=".85"/>'
        s += '<path d="M60,112 L58,80 L80,100 Z" fill="url(#cat)"/><path d="M104,104 L110,74 L122,100 Z" fill="url(#cat)"/>'
        s += '<ellipse cx="90" cy="126" rx="36" ry="26" fill="url(#cat)"/>'
        s += eyes(90, 124, 13, r=6, sleep=True) + cheeks(90, 136, 22, 5)
        s += zz(136, 92)
    return s

MASCOTS = [("quarki", "Quarki", "un quark", quarki), ("atomo", "Átomo", "el logo con carita", atomo),
           ("foton", "Fotón", "una chispita de luz", foton), ("gatito", "Gatito cuántico", "de energía", gatito)]

def svg(inner, w=200, h=200):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{GRAD}{inner}</svg>'

# ------------------------------------------------------------------ hoja con las 4
W, H = 1920, 1080
sheet = [f'<rect width="{W}" height="{H}" fill="#0E0A1C"/>',
         f'<text x="{W/2}" y="92" text-anchor="middle" font-family="Inter" font-weight="800" font-size="52" fill="#fff">¿Cuál será la mascota de Quantum?</text>',
         f'<text x="{W/2}" y="140" text-anchor="middle" font-family="Inter" font-size="24" fill="#A9A3D6">Despierta (cuando le hablas) y durmiendo en la barra de tareas</text>']
colw = W / 4
for i, (mid, name, sub, fn) in enumerate(MASCOTS):
    open(f"{mid}.svg", "w").write(svg(fn()))
    open(f"{mid}-duerme.svg", "w").write(svg(fn(True)))
    x0 = i * colw
    cx = x0 + colw / 2
    sheet.append(f'<rect x="{x0+24}" y="190" width="{colw-48}" height="840" rx="36" fill="#17112C" stroke="#2A2150" stroke-width="2"/>')
    sheet.append(f'<text x="{cx}" y="252" text-anchor="middle" font-family="Inter" font-weight="800" font-size="40" fill="#fff">{chr(65+i)}. {name}</text>')
    sheet.append(f'<text x="{cx}" y="290" text-anchor="middle" font-family="Inter" font-size="24" fill="#A9A3D6">{sub}</text>')
    # despierta, con globo de diálogo
    sheet.append(f'<g transform="translate({cx-150},330) scale(1.5)">{fn()}</g>')
    sheet.append(f'<rect x="{cx-170}" y="650" width="340" height="56" rx="28" fill="#251C47"/>')
    sheet.append(f'<text x="{cx}" y="687" text-anchor="middle" font-family="Inter" font-weight="600" font-size="23" fill="#E8E4FF">¡Hola! ¿Qué necesitas?</text>')
    # barra de tareas con la mascota durmiendo
    sheet.append(f'<text x="{cx}" y="790" text-anchor="middle" font-family="Inter" font-size="20" fill="#7E77AE">en la barra de tareas</text>')
    bx = cx - 190
    sheet.append(f'<rect x="{bx}" y="818" width="380" height="84" rx="22" fill="#221A3C" stroke="#342A5C" stroke-width="2"/>')
    for j, col in enumerate(("#4FD8FF", "#FF8A3D", "#22C58B", "#FFB547")):
        sheet.append(f'<rect x="{bx+24+j*62}" y="838" width="44" height="44" rx="12" fill="{col}" opacity=".85"/>')
    sheet.append(f'<g transform="translate({bx+282},814) scale(0.46)">{fn(True)}</g>')
    sheet.append(f'<g transform="translate({cx-60},918) scale(0.6)">{fn(True)}</g>')
open("opciones.svg", "w").write(svg("".join(sheet), W, H))
subprocess.run(["rsvg-convert", "opciones.svg", "-o", "opciones.png"], check=True)
print("listo")
