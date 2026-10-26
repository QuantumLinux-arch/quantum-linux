#!/usr/bin/env python3
"""Genera el arte del catálogo de Fotón (se corre a mano y el resultado se guarda en el repo).

- Juegos de Flathub: no tienen portadas oficiales, así que se arman con su captura
  de pantalla y su ícono: portada 600x900, banner 1920x620 y cabecera 460x215.
- Juegos de Steam: solo la cabecera 460x215 (para el instalador, que no tiene internet
  asegurado); Fotón usa la portada y el banner del CDN de Steam.

Uso: make-art.py   → escribe en art/ junto a este archivo
"""
import io
import json
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE / "art"
OUT.mkdir(exist_ok=True)
UA = {"User-Agent": "Foton/1.0 (Quantum Linux)"}
FONT = "/usr/share/fonts/inter/Inter.ttc"
STEAM = "https://shared.steamstatic.com/store_item_assets/steam/apps"


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
        return r.read()


def font(size):
    # índice de Inter.ttc con peso Black (se busca por nombre)
    for i in range(40):
        try:
            f = ImageFont.truetype(FONT, size, index=i)
        except OSError:
            break
        if f.getname() == ("Inter", "Black"):
            return f
    return ImageFont.truetype(FONT, size)


def cover_crop(img, w, h):
    """Recorta al centro para llenar w x h (como PreserveAspectCrop)."""
    k = max(w / img.width, h / img.height)
    img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    x, y = (img.width - w) // 2, (img.height - h) // 2
    return img.crop((x, y, x + w, y + h))


def shade(img, top=0.15, bottom=0.85):
    """Oscurece de arriba hacia abajo para que se lea lo que va encima."""
    w, h = img.size
    g = Image.linear_gradient("L").resize((w, h))
    dark = Image.new("RGB", (w, h), (8, 6, 18))
    mask = g.point(lambda v: int(255 * (top + (bottom - top) * v / 255)))
    return Image.composite(dark, img, mask)


def wrap(draw, text, f, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=f) <= width or not cur:
            cur = t
        else:
            lines.append(cur)
            cur = w
    return lines + [cur]


def flathub_art(g):
    d = json.loads(get(f"https://flathub.org/api/v2/appstream/{g['ref']}"))
    sizes = [z for s in d.get("screenshots", [])[:1] for z in s.get("sizes", []) if isinstance(z, dict)]
    sizes.sort(key=lambda z: -int(z.get("width") or 0))
    shot = Image.open(io.BytesIO(get(sizes[0]["src"]))).convert("RGB")
    icon = Image.open(io.BytesIO(get(d["icon"]))).convert("RGBA")

    # portada 600x900: captura desenfocada de fondo, la misma nítida arriba, ícono y nombre
    cov = cover_crop(shot, 600, 900).filter(ImageFilter.GaussianBlur(18))
    cov = shade(cov, 0.35, 0.9)
    top = cover_crop(shot, 600, 400)
    fade = Image.linear_gradient("L").resize((600, 400)).point(lambda v: 255 - v)
    cov.paste(top, (0, 0), fade)
    ic = icon.resize((200, 200), Image.LANCZOS)
    cov.paste(ic, (200, 400), ic)
    dr = ImageDraw.Draw(cov)
    f = font(52)
    lines = wrap(dr, g["name"], f, 520)[:3]
    y = 640
    for ln in lines:
        dr.text((300, y), ln, font=f, fill="white", anchor="ma")
        y += 62
    cov.save(OUT / f"{g['id']}-cover.jpg", quality=86)

    # banner 1920x620
    hero = shade(cover_crop(shot, 1920, 620), 0.1, 0.45)
    hero.save(OUT / f"{g['id']}-hero.jpg", quality=84)

    # cabecera 460x215 (instalador): captura con el ícono abajo a la izquierda
    hd = shade(cover_crop(shot, 460, 215), 0.0, 0.55)
    ic = icon.resize((84, 84), Image.LANCZOS)
    hd.paste(ic, (16, 215 - 84 - 14), ic)
    hd.save(OUT / f"{g['id']}-header.jpg", quality=86)


def steam_art(g):
    img = Image.open(io.BytesIO(get(f"{STEAM}/{g['ref']}/header.jpg"))).convert("RGB")
    cover_crop(img, 460, 215).save(OUT / f"{g['id']}-header.jpg", quality=86)


def main():
    games = json.loads((HERE / "catalog.json").read_text())["games"]
    for g in games:
        try:
            (flathub_art if g["kind"] == "flathub" else steam_art)(g)
            print("ok", g["id"])
        except Exception as e:
            print("FALLÓ", g["id"], e)


if __name__ == "__main__":
    main()
