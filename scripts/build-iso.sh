#!/usr/bin/env bash
# Construye el ISO de Quantum Linux. Necesita root (mkarchiso).
#
# Uso: sudo scripts/build-iso.sh
#   El ISO queda en out/. Ejecuta antes scripts/build-packages.sh como
#   usuario normal.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$ROOT/repo/x86_64"
WORK="$ROOT/build/iso-work"
PROFILE="$ROOT/build/profile"
OUT="$ROOT/out"

msg() { printf '\e[1;38;2;255;106;61m==>\e[0m \e[1m%s\e[0m\n' "$*"; }

if (( EUID != 0 )); then
    echo "Ejecuta este script con sudo: sudo $0" >&2
    exit 1
fi
if [[ ! -f "$REPO/quantum.db.tar.gz" ]]; then
    echo "Falta el repositorio local. Ejecuta primero scripts/build-packages.sh" >&2
    exit 1
fi

msg "Preparando el perfil"
rm -rf "$PROFILE"
cp -a "$ROOT/archiso" "$PROFILE"
sed -i "s|@QUANTUM_REPO@|$REPO|" "$PROFILE/pacman.conf"
latest() { ls "$REPO"/"$1"-[0-9]*.pkg.tar.zst | sort -V | tail -1; }
bsdtar -xOf "$(latest quantum-branding)" usr/share/quantum/iso/splash.png > "$PROFILE/syslinux/splash.png"

# El usuario en vivo no pasa por /etc/skel: se le copian los archivos
# iniciales (Hyprland, kitty) desde el paquete quantum-desktop.
live_home="$PROFILE/airootfs/home/liveuser"
mkdir -p "$live_home"
bsdtar -xf "$(latest quantum-desktop)" -C "$live_home" --strip-components 2 etc/skel

msg "Construyendo el ISO (tarda un rato)"
rm -rf "$WORK"
mkarchiso -v -r -w "$WORK" -o "$OUT" "$PROFILE"

# Arranque seguro: shim + systemd-boot y kernel firmados con la llave de Quantum
# (está en la carpeta personal del dueño, no en el repo). Si no está, el ISO queda sin firmar.
ISO="$(ls -t "$OUT"/*.iso | head -1)"
OWNER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
if [[ -f "$OWNER_HOME/.quantum-secureboot/quantum-sb.key" && -f "$ROOT/build/tools/sb/shim/boot/efi/EFI/BOOT/BOOTX64.EFI" ]]; then
    msg "Firmando para Secure Boot"
    QUANTUM_SB_KEYDIR="$OWNER_HOME/.quantum-secureboot" "$ROOT/scripts/sign-iso-secureboot.sh" "$ISO" "$ISO.firmado"
    mv -f "$ISO.firmado" "$ISO"
else
    msg "Aviso: sin llave de Secure Boot, el ISO no arranca con Secure Boot activado"
fi

if [[ -n "${SUDO_UID:-}" ]]; then
    chown "$SUDO_UID:$SUDO_GID" "$OUT" "$OUT"/*.iso
fi
msg "Listo: $(ls -t "$OUT"/*.iso | head -1)"
