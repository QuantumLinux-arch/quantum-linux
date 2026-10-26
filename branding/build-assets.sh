#!/usr/bin/env bash
# Renderiza todos los recursos gráficos de Quantum Linux a partir de los SVG.
# Uso: build-assets.sh <directorio-de-salida>
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$(realpath -m "${1:?Uso: build-assets.sh <directorio-de-salida>}")"
GEN="$HERE/generated"
INTER=/usr/share/fonts/inter/Inter.ttc

python3 "$HERE/generate.py" >/dev/null

svg() { rsvg-convert "$@"; }

# Íconos (hicolor): logo de la distro y versión simbólica para paneles
for s in 16 22 24 32 48 64 128 256 512; do
    d="$OUT/icons/hicolor/${s}x${s}/apps"
    mkdir -p "$d"
    svg -w "$s" -h "$s" "$GEN/quantum-icon.svg" -o "$d/quantum-linux.png"
done
mkdir -p "$OUT/icons/hicolor/scalable/apps"
cp "$GEN/quantum-icon.svg" "$OUT/icons/hicolor/scalable/apps/quantum-linux.svg"
cp "$HERE/src/quantum-mark.svg" "$OUT/icons/hicolor/scalable/apps/quantum-linux-mark.svg"
mkdir -p "$OUT/icons/hicolor/symbolic/apps"
cp "$GEN/quantum-mark-symbolic.svg" "$OUT/icons/hicolor/symbolic/apps/quantum-linux-symbolic.svg"

# Logos sueltos (shell, Centro Quantum, instalador, pantalla de inicio)
L="$OUT/logos"
mkdir -p "$L"
cp "$HERE/src/quantum-mark.svg" "$GEN/quantum-mark-light.svg" "$GEN/quantum-icon.svg" \
   "$GEN/quantum-wordmark-light.svg" "$GEN/quantum-wordmark-dark.svg" "$L/"
svg -w 512 "$HERE/src/quantum-mark.svg" -o "$L/quantum-mark.png"
svg -w 900 "$GEN/quantum-wordmark-light.svg" -o "$L/quantum-wordmark-light.png"
svg -w 900 "$GEN/quantum-wordmark-dark.svg" -o "$L/quantum-wordmark-dark.png"

# Fondos de pantalla
W="$OUT/wallpapers"
mkdir -p "$W/thumbs"
for name in orbita nucleo aurora; do
    svg -w 3840 -h 2160 "$GEN/wallpaper-$name.svg" -o "$W/$name.png"
    magick "$W/$name.png" -resize 480x270 "$W/thumbs/$name.jpg"
done

# Plymouth: logo, puntos de carga y cuadro de contraseña
P="$OUT/plymouth"
mkdir -p "$P"
svg -w 170 "$HERE/src/quantum-mark.svg" -o "$P/logo.png"
magick -size 12x12 xc:none -fill '#8F86FF' -draw 'circle 6,6 6,1' "$P/dot.png"
# Átomo animado: órbitas y cubo sin los electrones (los electrones se mueven en el script)
grep -v '<circle' "$HERE/src/quantum-mark.svg" > "$P/.atom.svg"
svg -w 360 "$P/.atom.svg" -o "$P/atom.png"; rm -f "$P/.atom.svg"
magick -size 26x26 xc:none -fill white -draw 'circle 13,13 13,2' -fill '#6A5CFF' -draw 'circle 13,13 13,8' "$P/electron.png"
for c in cyan:4FD8FF indigo:6A5CFF violet:B14DFF; do
    magick -size 18x18 xc:none -fill "#${c#*:}" -draw 'circle 9,9 9,2' -blur 0x1.2 "$P/trail-${c%%:*}.png"
done
magick -size 420x420 xc:none -fill '#6A5CFF' -draw 'circle 210,210 210,90' -blur 0x45 "$P/glow.png"
magick -size 5x5 xc:none -fill white -draw 'circle 2,2 2,0' "$P/star.png"
magick -size 10x10 xc:none -fill '#EEEAFB' -draw 'circle 5,5 5,1' "$P/bullet.png"
magick -size 320x46 xc:none -fill '#15121F' -stroke '#3A3352' -strokewidth 2 \
    -draw 'roundrectangle 1,1 318,44 12,12' "$P/entry.png"

# GRUB: fondo, logo, selección y fuentes
G="$OUT/grub"
mkdir -p "$G"
magick "$W/orbita.png" -resize 1920x1080 -fill '#07060D' -colorize 30% "$G/background.png"
svg -w 380 -h 108 "$GEN/quantum-wordmark-light.svg" -o "$G/logo.png"
magick -size 12x46 xc:'#6A5CFF33' "$G/select_c.png"
magick -size 4x46 xc:'#8F86FF' "$G/select_w.png"
magick -size 12x46 xc:'#6A5CFF33' "$G/select_e.png"
for p in n s nw ne sw se; do magick -size 1x1 xc:none "$G/select_$p.png"; done
for s in 16 20; do
    grub-mkfont -i 0 -s "$s" -n "Inter" -o "$G/inter-regular-$s.pf2" "$INTER"
done
grub-mkfont -i 14 -s 20 -n "Inter" -o "$G/inter-bold-20.pf2" "$INTER"

# Arranque del ISO (syslinux, 640x480)
mkdir -p "$OUT/iso"
svg -w 640 -h 360 "$GEN/wallpaper-nucleo.svg" -o "$OUT/iso/tmp.png"
magick "$OUT/iso/tmp.png" -background '#07060D' -gravity center -extent 640x480 "$OUT/iso/splash.png"
rm "$OUT/iso/tmp.png"

echo "Recursos generados en $OUT"
