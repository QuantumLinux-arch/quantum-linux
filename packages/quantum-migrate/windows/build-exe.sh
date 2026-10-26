#!/bin/bash
# Compila «Pasar a Quantum.exe» (desde Linux, con Rust + MinGW) y lo deja en files/ para el paquete
# y en el zip de la web. Se corre a mano cuando cambia el código de windows/.
set -euo pipefail
cd "$(dirname "$0")"
cargo build --release --target x86_64-pc-windows-gnu
install -Dm644 target/x86_64-pc-windows-gnu/release/pasar-a-quantum.exe "../files/Pasar a Quantum.exe"
rm -f ../files/pasar-a-quantum.zip
( cd ../files && cp LEEME.txt "LÉEME.txt" && zip -q -9 pasar-a-quantum.zip "Pasar a Quantum.exe" "LÉEME.txt" && rm "LÉEME.txt" )
ls -la "../files/Pasar a Quantum.exe" ../files/pasar-a-quantum.zip
