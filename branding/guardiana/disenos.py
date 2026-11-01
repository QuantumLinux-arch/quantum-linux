#!/usr/bin/env python3
"""Personaje original de Quantum: una pequeña guardiana de la biblioteca, chibi. Cuatro diseños
(pelo, coletas, ropa y accesorio distintos). El único guiño: dos coletas con moño rosado.
Genera <n>.svg y opciones.png."""
import subprocess

PINK, PINK_D = "#FF8FC8", "#E4579F"
SKIN, SKIN_S = "#FFE6D8", "#F6C9B5"


def bow(x, y, s=1.0, flip=False):
    k = -1 if flip else 1
    return (f'<g transform="translate({x},{y}) scale({k*s},{s})">'
            f'<path d="M0,0 C-10,-16 -30,-14 -28,2 C-26,14 -10,10 0,0 Z" fill="{PINK}" stroke="{PINK_D}" stroke-width="2"/>'
            f'<path d="M0,0 C10,-16 30,-14 28,2 C26,14 10,10 0,0 Z" fill="{PINK}" stroke="{PINK_D}" stroke-width="2"/>'
            f'<path d="M-3,2 L-12,26 L-4,22 L0,30 Z M3,2 L12,24 L5,21 Z" fill="{PINK_D}"/>'
            f'<circle r="6" fill="{PINK_D}"/></g>')


def tails(style, hair, shade):
    s = ""
    for side in (-1, 1):
        x0 = 120 + side * 58
        if style == "lisa":        # coletas lisas y largas
            s += (f'<path d="M{x0},78 C{x0+side*30},110 {x0+side*26},190 {x0+side*12},232 '
                  f'C{x0+side*4},210 {x0-side*8},150 {x0-side*10},96 Z" fill="{hair}" stroke="{shade}" stroke-width="2"/>')
            s += f'<path d="M{x0+side*6},110 C{x0+side*16},150 {x0+side*14},190 {x0+side*10},214" fill="none" stroke="{shade}" stroke-width="2" opacity=".6"/>'
        elif style == "ondas":     # coletas onduladas (curvas suaves, no espirales)
            s += (f'<path d="M{x0},78 C{x0+side*34},104 {x0+side*6},138 {x0+side*30},166 '
                  f'C{x0+side*48},190 {x0+side*20},214 {x0+side*26},236 C{x0+side*6},222 {x0+side*4},200 {x0+side*8},178 '
                  f'C{x0+side*12},156 {x0-side*14},132 {x0-side*8},96 Z" fill="{hair}" stroke="{shade}" stroke-width="2"/>')
        elif style == "trenza":    # trenzas
            for i in range(6):
                cy = 98 + i * 23
                cx = x0 + side * (8 + (i % 2) * 4)
                r = 15 - i * 1.3
                s += f'<ellipse cx="{cx}" cy="{cy}" rx="{r}" ry="{r*0.9+2}" fill="{hair}" stroke="{shade}" stroke-width="2"/>'
            s += f'<circle cx="{x0+side*10}" cy="{98+6*23-4}" r="5" fill="{PINK}"/>'
        elif style == "cortas":    # coletas cortas y esponjosas
            s += (f'<path d="M{x0},76 C{x0+side*44},70 {x0+side*56},120 {x0+side*34},150 '
                  f'C{x0+side*28},132 {x0+side*14},120 {x0-side*6},100 Z" fill="{hair}" stroke="{shade}" stroke-width="2"/>')
        s += bow(x0 + side * 2, 76, 0.9, side < 0)
    return s


def head(hair, shade, eye):
    s = f'<ellipse cx="120" cy="104" rx="66" ry="60" fill="{hair}" stroke="{shade}" stroke-width="2"/>'      # pelo de atrás
    s += f'<ellipse cx="120" cy="112" rx="54" ry="50" fill="{SKIN}"/>'                                     # cara
    # flequillo
    s += (f'<path d="M58,104 C56,58 92,42 120,42 C150,42 186,58 182,104 C172,92 166,80 160,74 C156,90 146,96 138,98 '
          f'C136,86 132,78 126,72 C120,88 108,96 96,98 C98,86 96,80 92,74 C84,86 72,96 58,104 Z" fill="{hair}" stroke="{shade}" stroke-width="2"/>')
    s += f'<path d="M78,60 C92,50 108,48 118,50" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity=".45"/>'
    # ojos grandes
    for x in (98, 142):
        s += (f'<ellipse cx="{x}" cy="122" rx="12" ry="15" fill="#fff"/>'
              f'<ellipse cx="{x}" cy="124" rx="10" ry="13" fill="{eye}"/>'
              f'<ellipse cx="{x}" cy="128" rx="6" ry="8" fill="#1B1240" opacity=".55"/>'
              f'<circle cx="{x+4}" cy="117" r="4" fill="#fff"/><circle cx="{x-4}" cy="130" r="2" fill="#fff" opacity=".8"/>'
              f'<path d="M{x-13},108 Q{x},102 {x+13},108" fill="none" stroke="#3A2A4A" stroke-width="3" stroke-linecap="round"/>')
    s += f'<ellipse cx="84" cy="140" rx="8" ry="4" fill="{PINK}" opacity=".45"/><ellipse cx="156" cy="140" rx="8" ry="4" fill="{PINK}" opacity=".45"/>'
    s += '<path d="M114,146 Q120,151 126,146" fill="none" stroke="#7A3A50" stroke-width="2.4" stroke-linecap="round"/>'
    return s


def body(dress, dress_d, trim):
    s = (f'<path d="M92,160 L148,160 L172,248 C150,256 90,256 68,248 Z" fill="{dress}" stroke="{dress_d}" stroke-width="2"/>'
         f'<path d="M70,240 C90,250 150,250 170,240 L172,248 C150,256 90,256 68,248 Z" fill="{trim}"/>')
    # brazos y manos
    s += (f'<path d="M94,164 C78,176 72,196 76,210" fill="none" stroke="{dress}" stroke-width="14" stroke-linecap="round"/>'
          f'<path d="M146,164 C162,176 168,196 164,210" fill="none" stroke="{dress}" stroke-width="14" stroke-linecap="round"/>'
          f'<circle cx="76" cy="214" r="7" fill="{SKIN}"/><circle cx="164" cy="214" r="7" fill="{SKIN}"/>')
    # piernas y zapatos
    s += ('<rect x="102" y="252" width="12" height="20" rx="5" fill="#4A3A6A"/><rect x="126" y="252" width="12" height="20" rx="5" fill="#4A3A6A"/>'
          '<ellipse cx="108" cy="274" rx="10" ry="6" fill="#2A1E44"/><ellipse cx="132" cy="274" rx="10" ry="6" fill="#2A1E44"/>')
    return s


def atom_clasp(x, y):
    return (f'<g transform="translate({x},{y})"><circle r="9" fill="#1B1240"/>'
            + "".join(f'<ellipse rx="7" ry="2.6" fill="none" stroke="#7FE3FF" stroke-width="1.6" transform="rotate({a})"/>' for a in (0, 60, -60))
            + '<circle r="1.8" fill="#fff"/></g>')


def cape(c, d):
    return (f'<path d="M86,158 C70,190 62,226 60,250 L90,236 L120,252 L150,236 L180,250 C178,226 170,190 154,158 Z" '
            f'fill="{c}" stroke="{d}" stroke-width="2" opacity=".95"/>')


def book(x, y):
    return (f'<g transform="translate({x},{y}) rotate(-12)"><rect x="-22" y="-15" width="44" height="30" rx="4" fill="#6A5CFF"/>'
            '<rect x="-19" y="-12" width="18" height="24" rx="2" fill="#F4F1FF"/><rect x="1" y="-12" width="18" height="24" rx="2" fill="#F4F1FF"/>'
            '<path d="M-15,-6 h11 M-15,-1 h11 M-15,4 h8 M5,-6 h11 M5,-1 h11 M5,4 h8" stroke="#B7AEE8" stroke-width="1.6"/>'
            '<circle cx="0" cy="-22" r="3" fill="#7FE3FF"/><circle cx="14" cy="-26" r="2" fill="#E3B8FF"/></g>')


def orb(x, y):
    return (f'<circle cx="{x}" cy="{y}" r="22" fill="#7FE3FF" opacity=".25"/><circle cx="{x}" cy="{y}" r="13" fill="url(#orb)"/>'
            f'<circle cx="{x-4}" cy="{y-4}" r="4" fill="#fff" opacity=".8"/>')


def glasses():
    return ('<g fill="none" stroke="#4A3A6A" stroke-width="3"><circle cx="98" cy="122" r="17"/><circle cx="142" cy="122" r="17"/>'
            '<path d="M115,120 Q120,116 125,120"/></g>')


DEFS = ('<defs><radialGradient id="orb" cx=".35" cy=".35"><stop offset="0" stop-color="#fff"/><stop offset=".5" stop-color="#4FD8FF"/>'
        '<stop offset="1" stop-color="#6A5CFF"/></radialGradient></defs>')

DESIGNS = [
    ("1", "Lila", "pelo lavanda, coletas lisas, capa cian con el átomo y un libro que flota",
     dict(hair="#C9B6FF", shade="#9C86E8", eye="#4FD8FF", tails="lisa", dress="#6A5CFF", dress_d="#4E3FD6", trim="#B9B0FF",
          extra=lambda: cape("#3FC6EE", "#2AA3C9") + atom_clasp(120, 166), acc=lambda: book(196, 150))),
    ("2", "Estela", "pelo plateado, coletas onduladas, vestido violeta y una esfera de luz",
     dict(hair="#E4E8F4", shade="#B5BCD6", eye="#B14DFF", tails="ondas", dress="#B14DFF", dress_d="#8A2FD6", trim="#F2D9FF",
          extra=lambda: atom_clasp(120, 172), acc=lambda: orb(198, 146))),
    ("3", "Nori", "pelo menta, trenzas, lentes redondos y uniforme de bibliotecaria",
     dict(hair="#8FE3CF", shade="#5CBFA8", eye="#6A5CFF", tails="trenza", dress="#2E3A66", dress_d="#1E2850", trim="#4FD8FF",
          extra=lambda: glasses() + atom_clasp(120, 174), acc=lambda: book(42, 160))),
    ("4", "Nova", "pelo azul noche con puntas cian, coletas cortas y capa de estrellas",
     dict(hair="#2B3170", shade="#1B1F4E", eye="#4FD8FF", tails="cortas", dress="#4FD8FF", dress_d="#2AA3C9", trim="#FFFFFF",
          extra=lambda: cape("#1B1240", "#0E0A2A") + '<g fill="#fff">' + "".join(f'<circle cx="{x}" cy="{y}" r="1.8"/>' for x, y in ((84, 200), (152, 214), (100, 230), (140, 186), (162, 238))) + '</g>' + atom_clasp(120, 166),
          acc=lambda: orb(40, 150))),
]


def character(d):
    return (DEFS + tails(d["tails"], d["hair"], d["shade"]) + body(d["dress"], d["dress_d"], d["trim"]) + d["extra"]()
            + head(d["hair"], d["shade"], d["eye"]) + d["acc"]())


def svg(inner, w=240, h=290):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{inner}</svg>'


W, H = 1920, 900
sheet = [f'<rect width="{W}" height="{H}" fill="#0E0A1C"/>',
         f'<text x="{W/2}" y="80" text-anchor="middle" font-family="Inter" font-weight="800" font-size="50" fill="#fff">La guardiana de Quantum: ¿cuál te gusta?</text>',
         f'<text x="{W/2}" y="124" text-anchor="middle" font-family="Inter" font-size="23" fill="#A9A3D6">Personaje original · el guiño: dos coletas con moño rosado</text>']
for i, (n, name, desc, d) in enumerate(DESIGNS):
    inner = character(d)
    open(f"{n}.svg", "w").write(svg(inner))
    x0 = 40 + i * 470
    sheet.append(f'<rect x="{x0}" y="160" width="440" height="700" rx="34" fill="#17112C" stroke="#2A2150" stroke-width="2"/>')
    sheet.append(f'<g transform="translate({x0+40},190) scale(1.5)">{inner}</g>')
    sheet.append(f'<text x="{x0+220}" y="676" text-anchor="middle" font-family="Inter" font-weight="800" font-size="36" fill="#fff">{n}. {name}</text>')
    words, lines, cur = desc.split(), [], ""
    for w in words:
        if len(cur) + len(w) > 34: lines.append(cur); cur = w
        else: cur = (cur + " " + w).strip()
    lines.append(cur)
    for j, l in enumerate(lines):
        sheet.append(f'<text x="{x0+220}" y="{716+j*30}" text-anchor="middle" font-family="Inter" font-size="21" fill="#A9A3D6">{l}</text>')
open("opciones.svg", "w").write(svg("".join(sheet), W, H))
subprocess.run(["rsvg-convert", "opciones.svg", "-o", "opciones.png"], check=True)
print("listo")
