#!/usr/bin/env bash
# Escribe website/descargas/latest.json con el ISO más nuevo de out/ (lo lee el instalador para Windows).
# Usar después de subir ese mismo ISO a SourceForge con upload-sourceforge.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO="$(ls -t "$ROOT"/out/quantumlinux-*.iso | head -1)"
NAME="$(basename "$ISO")"
VER="${NAME#quantumlinux-}"; VER="${VER%-x86_64.iso}"
SHA="$(cut -d' ' -f1 "$ISO.sha256" 2>/dev/null || sha256sum "$ISO" | cut -d' ' -f1)"
printf '{"version":"%s","url":"https://downloads.sourceforge.net/project/quantum-linux/1.0/%s","sha256":"%s","size":%s}\n' \
    "$VER" "$NAME" "$SHA" "$(stat -c %s "$ISO")" > "$ROOT/website/descargas/latest.json"
cat "$ROOT/website/descargas/latest.json"
