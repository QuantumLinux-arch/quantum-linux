#!/usr/bin/env bash
# Sube el ISO más reciente de out/ a SourceForge, con su suma SHA256.
# Uso: scripts/upload-sourceforge.sh <usuario-sourceforge> [proyecto]
#   proyecto: el nombre corto del proyecto en SourceForge (por defecto quantum-linux)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_SF="${1:?Uso: $0 <usuario-sourceforge> [proyecto]}"
PROJECT="${2:-quantum-linux}"
ISO="$(ls -t "$ROOT"/out/quantumlinux-*.iso | head -1)"
NAME="$(basename "$ISO")"

msg() { printf '\e[1;38;2;143;123;255m==>\e[0m \e[1m%s\e[0m\n' "$*"; }

msg "ISO: $NAME ($(du -h "$ISO" | cut -f1))"
msg "Calculando la suma SHA256 (para que la gente compruebe la descarga)"
(cd "$(dirname "$ISO")" && sha256sum "$NAME" > "$NAME.sha256")
cat "$ISO.sha256"

msg "Subiendo a SourceForge (te pedirá la contraseña de tu cuenta)"
# --partial permite retomar si se corta la conexión: vuelve a ejecutar el script
rsync -avP --partial -e "${RSYNC_RSH:-ssh}" "$ISO" "$ISO.sha256" \
    "$USER_SF@frs.sourceforge.net:/home/frs/project/$PROJECT/1.0/"

msg "Listo. Enlace de descarga:"
echo "https://sourceforge.net/projects/$PROJECT/files/1.0/$NAME/download"
