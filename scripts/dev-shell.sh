#!/usr/bin/env bash
# Prueba el escritorio de Quantum (Wayfire + Quantum Shell) en una ventana,
# con un HOME de prueba en build/dev-home y su propio D-Bus: no toca tu sesión.
#
# Uso: scripts/dev-shell.sh            abre Wayfire anidado
#      scripts/dev-shell.sh --reset    borra el HOME de prueba antes
# Variables opcionales: WAYFIRE (binario), WAYFIRE_PREFIX (prefijo con lib/ y share/
# si Wayfire no está instalado, p. ej. extraído de los paquetes).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV="$ROOT/build/dev-home"
SHARE="$ROOT/build/dev-share"
FONT_URL="https://raw.githubusercontent.com/google/material-design-icons/49d4db35df873165d6bd6ba09b063c7dafbac2f4/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"

[[ "${1:-}" == "--reset" ]] && rm -rf "$DEV"
mkdir -p "$DEV"/{.config/quickshell,.config/quantum,.local/share/fonts,.local/state,bin} "$SHARE"

[[ -f "$ROOT/build/assets/wallpapers/orbita.png" ]] || "$ROOT/branding/build-assets.sh" "$ROOT/build/assets" >/dev/null
font="$DEV/.local/share/fonts/MaterialSymbolsRounded.ttf"
[[ -f "$font" ]] || curl -sSfL -o "$font" "$FONT_URL"

D="$ROOT/packages/quantum-desktop/files"
ln -sfn "$ROOT/packages/quantum-shell/files/quantum" "$DEV/.config/quickshell/quantum"
for b in quantum-theme quantum-screenshot; do ln -sf "$D/bin/$b" "$DEV/bin/$b"; done
ln -sf "$D/share/palette.json" "$SHARE/palette.json"
ln -sfn "$D/wayfire" "$SHARE/wayfire"
[[ -f "$DEV/.config/quantum/settings.json" ]] || cat > "$DEV/.config/quantum/settings.json" <<JSON
{ "appearance": { "mode": "dark", "dynamicColors": false, "wallpaper": "$ROOT/build/assets/wallpapers/orbita.png" } }
JSON

wayfire_bin="${WAYFIRE:-wayfire}"
extra_env=()
extra_args=()
if [[ -n "${WAYFIRE_PREFIX:-}" ]]; then
    wayfire_bin="$WAYFIRE_PREFIX/usr/bin/wayfire"
    extra_env=(LD_LIBRARY_PATH="$WAYFIRE_PREFIX/usr/lib"
               WAYFIRE_PLUGIN_PATH="$WAYFIRE_PREFIX/usr/lib/wayfire"
               WAYFIRE_PLUGIN_XML_PATH="$WAYFIRE_PREFIX/usr/share/wayfire/metadata")
    extra_args=(-B "$WAYFIRE_PREFIX/usr/lib/wayfire/libdefault-config-backend.so")
fi

export QUANTUM_WAYFIRE_PC="${WAYFIRE_PREFIX:-}/usr/lib/pkgconfig/wayfire.pc"
export HOME="$DEV" XDG_CONFIG_HOME="$DEV/.config" XDG_STATE_HOME="$DEV/.local/state" \
       XDG_DATA_HOME="$DEV/.local/share" PATH="$DEV/bin:$PATH" QUANTUM_DEV=1 \
       QUANTUM_SHARE="$SHARE" GSETTINGS_BACKEND=memory XCURSOR_THEME=Adwaita \
       QUANTUM_SHELL_CMD="${QUANTUM_SHELL_CMD:-qs -c quantum}"
quantum-theme apply
exec dbus-run-session -- env "${extra_env[@]}" "$wayfire_bin" "${extra_args[@]}" -c "$DEV/.local/state/quantum/wayfire.ini"
