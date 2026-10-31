"""Ícono de Archivos (quantum-files), a juego con los de Personalizar, la Tienda y el Asistente."""
import subprocess
SQ = "M128 8C40 8 8 40 8 128s32 120 120 120 120-32 120-120S216 8 128 8z"
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#4FD8FF"/><stop offset="0.55" stop-color="#6A5CFF"/><stop offset="1" stop-color="#B14DFF"/></linearGradient>
  <linearGradient id="hl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.18"/><stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
  <linearGradient id="front" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E9E6FF"/></linearGradient>
  <filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="6" stdDeviation="7" flood-color="#1B0F5C" flood-opacity="0.35"/></filter>
</defs>
<path d="{SQ}" fill="url(#bg)"/><path d="{SQ}" fill="url(#hl)"/>
<g filter="url(#sh)">
  <path d="M52 84a14 14 0 0 1 14-14h40l16 16h68a14 14 0 0 1 14 14v8H52z" fill="#D9D3FF"/>
  <rect x="52" y="98" width="152" height="96" rx="14" fill="url(#front)"/>
</g>
<rect x="76" y="124" width="56" height="9" rx="4.5" fill="#6A5CFF" opacity="0.9"/>
<rect x="76" y="144" width="88" height="9" rx="4.5" fill="#B14DFF" opacity="0.45"/>
<rect x="76" y="164" width="40" height="9" rx="4.5" fill="#4FD8FF" opacity="0.7"/>
</svg>'''
open("archivos.svg", "w").write(svg)
subprocess.run(["rsvg-convert", "-w", "220", "archivos.svg", "-o", "archivos.png"], check=True)
print("ok")
