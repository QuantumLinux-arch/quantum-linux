#!/usr/bin/env bash
# Publica el repositorio [quantum] en GitHub para que los sistemas instalados
# reciban las mejoras con una actualización normal (pacman -Syu).
#
# Firma cada paquete y la base de datos con la clave de Quantum
# (~/.quantum-signing) y los sube a la Release «x86_64» de
# github.com/QuantumLinux-arch/quantum-repo.
#
# Uso: scripts/publish-repo.sh      (antes: scripts/build-packages.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/repo/x86_64"
OUT="$ROOT/build/publish/x86_64"
GH_REPO="QuantumLinux-arch/quantum-repo"
TAG="x86_64"
export GNUPGHOME="${QUANTUM_GNUPGHOME:-$HOME/.quantum-signing}"
KEY="${QUANTUM_KEY:-A8C645AA66BB440580DE596BD416458B54B290FA}"

msg() { printf '\e[1;38;2;143;123;255m==>\e[0m \e[1m%s\e[0m\n' "$*"; }

[[ -d "$GNUPGHOME" ]] || { echo "No encuentro la clave de firma en $GNUPGHOME" >&2; exit 1; }

msg "Preparando los paquetes"
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$SRC"/*.pkg.tar.zst "$OUT/"
cd "$OUT"

msg "Firmando $(ls *.pkg.tar.zst | wc -l) paquetes"
for p in *.pkg.tar.zst; do
    gpg --batch --yes --quiet --local-user "$KEY" --detach-sign --no-armor "$p"
done

msg "Creando la base de datos firmada"
# en orden de versión (ls -v): en orden alfabético «-10» queda antes que «-9» y la base apuntaría al viejo
repo-add -q -s -k "$KEY" quantum.db.tar.gz $(ls -v ./*.pkg.tar.zst)
# GitHub no guarda enlaces simbólicos: se suben archivos reales con el nombre que pide pacman
for f in quantum.db quantum.db.sig quantum.files quantum.files.sig; do
    [[ -L "$f" ]] && cp --remove-destination "$(readlink "$f")" "$f"
done
rm -f quantum.db.tar.gz quantum.db.tar.gz.sig quantum.files.tar.gz quantum.files.tar.gz.sig

if ! gh repo view "$GH_REPO" >/dev/null 2>&1; then
    msg "Creando el repositorio $GH_REPO"
    gh repo create "$GH_REPO" --public --description "Repositorio de paquetes de Quantum Linux (pacman)" >/dev/null
fi
if ! gh release view "$TAG" --repo "$GH_REPO" >/dev/null 2>&1; then
    gh release create "$TAG" --repo "$GH_REPO" --title "Paquetes de Quantum Linux (x86_64)" \
        --notes "Repositorio de pacman de Quantum Linux. No descargues estos archivos a mano: Quantum los usa para actualizarse solo." >/dev/null
fi

# Solo se sube lo que GitHub no tiene igual (mismo nombre y mismo tamaño): una publicación
# normal pasa de ~165 MB a unos pocos. Si un paquete cambió sin subir de versión, su tamaño
# cambia y se vuelve a subir, así la base de datos nunca queda descuadrada.
declare -A remote_size
while IFS=$'\t' read -r name size; do remote_size["$name"]=$size; done \
    < <(gh release view "$TAG" --repo "$GH_REPO" --json assets --jq '.assets[] | [.name, .size] | @tsv')
new=()
for f in ./*.pkg.tar.zst; do
    f=${f#./}
    if [[ "${remote_size[$f]:-}" != "$(stat -c %s "$f")" ]]; then
        new+=("$f" "$f.sig")
    fi
done
msg "Subiendo a GitHub ($(( ${#new[@]} / 2 )) paquetes nuevos de $(ls *.pkg.tar.zst | wc -l))"
# primero lo nuevo (paquetes y luego la base de datos que los menciona)…
(( ${#new[@]} )) && gh release upload "$TAG" --repo "$GH_REPO" --clobber "${new[@]}"
gh release upload "$TAG" --repo "$GH_REPO" --clobber quantum.db quantum.db.sig quantum.files quantum.files.sig
# …y después se borran las versiones viejas que ya nadie pide
mapfile -t remote < <(gh release view "$TAG" --repo "$GH_REPO" --json assets --jq '.assets[].name')
for a in "${remote[@]}"; do
    [[ -e "$a" ]] || gh release delete-asset "$TAG" "$a" --repo "$GH_REPO" --yes >/dev/null
done
msg "Listo: https://github.com/$GH_REPO/releases/tag/$TAG"
