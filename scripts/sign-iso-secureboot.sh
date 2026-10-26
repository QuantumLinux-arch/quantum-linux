#!/usr/bin/env bash
# Hace que un ISO de Quantum arranque con Secure Boot activado (no necesita sudo):
#   - EFI/BOOT/BOOTx64.EFI  = shim de Fedora (firmado por Microsoft)
#   - EFI/BOOT/grubx64.efi  = systemd-boot del ISO, firmado con la llave de Quantum
#   - EFI/BOOT/mmx64.efi    = MokManager (firmado por Fedora), para registrar la llave
#   - quantum.cer           = certificado público de Quantum, para registrarlo a mano
#   - el kernel del sistema en vivo, firmado con la llave de Quantum
# La primera vez el PC muestra MokManager para registrar la llave (el instalador de
# Windows lo deja preparado). La llave privada está en ~/.quantum-secureboot (nunca en el repo).
#
# Uso: scripts/sign-iso-secureboot.sh ENTRADA.iso SALIDA.iso
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IN="$1"; OUT="$2"
KEYDIR="${QUANTUM_SB_KEYDIR:-$HOME/.quantum-secureboot}"
TOOLS="$ROOT/build/tools/sb"
SBSIGN="$(command -v sbsign || echo "$TOOLS/usr/bin/sbsign")"
SHIM="$TOOLS/shim/boot/efi/EFI/BOOT/BOOTX64.EFI"
MM="$TOOLS/shim/boot/efi/EFI/fedora/mmx64.efi"
[[ -f "$KEYDIR/quantum-sb.key" ]] || { echo "Falta la llave en $KEYDIR" >&2; exit 1; }
[[ -f "$SHIM" && -f "$MM" ]] || { echo "Falta el shim de Fedora en $TOOLS/shim (ver HANDOFF)" >&2; exit 1; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
sign() { "$SBSIGN" --key "$KEYDIR/quantum-sb.key" --cert "$KEYDIR/quantum-sb.crt" --output "$2" "$1" >/dev/null; }

echo "==> Sacando la imagen EFI del ISO"
xorriso -osirrox on -indev "$IN" -extract_boot_images "$W/boot/" >/dev/null 2>&1
EFI="$W/efiboot.img"; cp "$W/boot/eltorito_img2_uefi.img" "$EFI"
export MTOOLS_SKIP_CHECK=1

echo "==> Firmando el arranque y el kernel"
mcopy -n -i "$EFI" ::/EFI/BOOT/BOOTx64.EFI "$W/systemd-boot.efi"
sign "$W/systemd-boot.efi" "$W/grubx64.efi"
KERN=$(mdir -b -i "$EFI" ::/quantum/boot/x86_64/ | grep -i vmlinuz | head -1)
mcopy -n -i "$EFI" "::${KERN#::}" "$W/vmlinuz"
sign "$W/vmlinuz" "$W/vmlinuz.signed"

mcopy -o -i "$EFI" "$SHIM" ::/EFI/BOOT/BOOTx64.EFI
mcopy -o -i "$EFI" "$W/grubx64.efi" ::/EFI/BOOT/grubx64.efi
mcopy -o -i "$EFI" "$MM" ::/EFI/BOOT/mmx64.efi
mcopy -o -i "$EFI" "$KEYDIR/quantum-sb.cer" ::/quantum.cer
mcopy -o -i "$EFI" "$W/vmlinuz.signed" "::${KERN#::}"

echo "==> Armando el ISO nuevo"
KPATH="${KERN#::}"
rm -f "$OUT"
# -joliet on: sin Joliet, Windows ve los nombres en MAYÚSCULAS y con «_» en vez de «-» (el instalador para Windows copia el ISO)
xorriso -indev "$IN" -outdev "$OUT" -boot_image any replay -joliet on -compliance joliet_long_names \
  -append_partition 2 0xef "$EFI" \
  -map "$SHIM" /EFI/BOOT/BOOTx64.EFI -map "$W/grubx64.efi" /EFI/BOOT/grubx64.efi \
  -map "$MM" /EFI/BOOT/mmx64.efi -map "$KEYDIR/quantum-sb.cer" /quantum.cer \
  -map "$W/vmlinuz.signed" "$KPATH" >/dev/null 2>&1
echo "Listo: $OUT"
