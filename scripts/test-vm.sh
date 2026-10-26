#!/usr/bin/env bash
# Prueba el ISO más reciente en QEMU.
#
# Uso: scripts/test-vm.sh [--bios] [--disk-only] [--reset]
#   --bios       arranca en modo BIOS en lugar de UEFI
#   --disk-only  arranca el disco virtual sin el ISO (después de instalar)
#   --reset      borra el disco virtual y empieza de cero
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VM="$ROOT/build/vm"
DISK="$VM/disk.qcow2"
OVMF_CODE=/usr/share/edk2/x64/OVMF_CODE.4m.fd
OVMF_VARS_SRC=/usr/share/edk2/x64/OVMF_VARS.4m.fd

uefi=1; with_iso=1
for a in "$@"; do
    case "$a" in
        --bios) uefi=0 ;;
        --disk-only) with_iso=0 ;;
        --reset) rm -f "$DISK" "$VM/OVMF_VARS.fd" ;;
        *) echo "Opción desconocida: $a" >&2; exit 1 ;;
    esac
done

mkdir -p "$VM"
[[ -f "$DISK" ]] || qemu-img create -f qcow2 "$DISK" 60G

args=(
    -enable-kvm -machine q35 -cpu host -smp 4 -m 6G
    -device virtio-vga-gl -display gtk,gl=on
    -device intel-hda -device hda-duplex
    -nic user,model=virtio-net-pci
    -drive file="$DISK",if=virtio,format=qcow2
    -usb -device usb-tablet
)
if (( uefi )); then
    [[ -f "$VM/OVMF_VARS.fd" ]] || cp "$OVMF_VARS_SRC" "$VM/OVMF_VARS.fd"
    args+=(-drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE"
           -drive if=pflash,format=raw,file="$VM/OVMF_VARS.fd")
fi
if (( with_iso )); then
    iso="$(ls -t "$ROOT"/out/*.iso 2>/dev/null | head -1)"
    [[ -n "$iso" ]] || { echo "No hay ISO en out/. Ejecuta scripts/build-iso.sh" >&2; exit 1; }
    args+=(-cdrom "$iso" -boot order=d)
fi

exec qemu-system-x86_64 "${args[@]}"
