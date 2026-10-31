"""Opciones de ícono para Personalizar, a juego con los de Quantum Store y el Asistente
(forma «squircle», fondo con degradado, dibujo plano con una sombra suave)."""
import subprocess

SQ = "M128 8C40 8 8 40 8 128s32 120 120 120 120-32 120-120S216 8 128 8z"


def base(c1, c2, hl=0.16):
    return f'''<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>
  <linearGradient id="hl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="{hl}"/><stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
  <linearGradient id="rb" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#4FD8FF"/><stop offset="0.5" stop-color="#6A5CFF"/><stop offset="1" stop-color="#B14DFF"/></linearGradient>
  <filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="6" stdDeviation="7" flood-color="#000" flood-opacity="0.25"/></filter>
</defs>
<path d="{SQ}" fill="url(#bg)"/><path d="{SQ}" fill="url(#hl)"/>'''


OPTIONS = {
    # A: pincel pintando un trazo con los colores de Quantum
    "A-pincel": (("#2B2350", "#15102C"), '''
<path d="M54 196c22-4 40-22 56-24 18-2 24 18 10 28-16 12-48 8-66-4z" fill="url(#rb)"/>
<g filter="url(#sh)">
  <path d="M188 52l20 20-70 76-26-26z" fill="#FFFFFF"/>
  <path d="M110 124l26 26c-6 18-22 30-44 30 2-24 4-46 18-56z" fill="#FFD36B"/>
</g>'''),
    # B: paleta de pintor con cuatro colores
    "B-paleta": (("#6A5CFF", "#B14DFF"), '''
<g filter="url(#sh)">
  <path d="M128 50c48 0 84 32 84 72 0 26-20 34-38 30-14-3-22 8-16 20 8 16-4 34-30 34-46 0-82-34-82-78s36-78 82-78z" fill="#FFFFFF"/>
</g>
<circle cx="92" cy="104" r="15" fill="#4FD8FF"/><circle cx="132" cy="84" r="15" fill="#FFD36B"/>
<circle cx="172" cy="106" r="15" fill="#FF6B8B"/><circle cx="86" cy="148" r="15" fill="#22C58B"/>'''),
    # C: ventana con tres deslizadores (ajustes del escritorio)
    "C-ajustes": (("#14B8A6", "#0E7C72"), '''
<g filter="url(#sh)">
  <rect x="44" y="56" width="168" height="144" rx="22" fill="#FFFFFF"/>
</g>
<rect x="44" y="56" width="168" height="30" rx="22" fill="#D7F5F0"/><rect x="44" y="72" width="168" height="14" fill="#D7F5F0"/>
<g stroke-linecap="round" stroke-width="10">
  <path d="M70 116h116M70 146h116M70 176h116" stroke="#CDE7E3"/>
  <path d="M70 116h70M70 146h28M70 176h92" stroke="#14B8A6"/>
</g>
<circle cx="140" cy="116" r="12" fill="#0E7C72"/><circle cx="98" cy="146" r="12" fill="#0E7C72"/><circle cx="162" cy="176" r="12" fill="#0E7C72"/>'''),
    # D: varita mágica con chispas (cambiar todo con un clic)
    "D-varita": (("#FF7AA8", "#B14DFF"), '''
<g filter="url(#sh)">
  <path d="M60 196l96-96 20 20-96 96z" fill="#FFFFFF"/>
  <path d="M156 100l20 20 14-14-20-20z" fill="#FFE7A8"/>
</g>
<path d="M164 46c4 18 10 24 28 28-18 4-24 10-28 28-4-18-10-24-28-28 18-4 24-10 28-28z" fill="#FFFFFF"/>
<path d="M206 108c2 9 5 12 14 14-9 2-12 5-14 14-2-9-5-12-14-14 9-2 12-5 14-14z" fill="#FFE7A8"/>
<path d="M112 52c2 8 4 10 12 12-8 2-10 4-12 12-2-8-4-10-12-12 8-2 10-4 12-12z" fill="#FFE7A8"/>'''),
    # E: monitor con un fondo que se está pintando (un rodillo)
    "E-escritorio": (("#1B2A55", "#0E1630"), '''
<g filter="url(#sh)">
  <rect x="40" y="58" width="176" height="118" rx="16" fill="#FFFFFF"/>
  <path d="M104 196h48M128 176v20" stroke="#FFFFFF" stroke-width="12" stroke-linecap="round"/>
</g>
<rect x="52" y="70" width="152" height="94" rx="8" fill="#E9ECF5"/>
<path d="M52 140c30-20 56 6 86-10s46-6 66 4v22a8 8 0 0 1-8 8H60a8 8 0 0 1-8-8z" fill="url(#rb)"/>
<circle cx="170" cy="96" r="12" fill="#FFD36B"/>'''),
    # F: rodillo de pintura con un trazo arcoíris
    "F-rodillo": (("#FF8A5B", "#F0506E"), '''
<path d="M40 182c40-26 88-26 176 0v26H40z" fill="url(#rb)" opacity="0.95"/>
<g filter="url(#sh)">
  <rect x="58" y="46" width="128" height="44" rx="14" fill="#FFFFFF"/>
  <path d="M186 68h18v40h-80v26" fill="none" stroke="#FFFFFF" stroke-width="12" stroke-linejoin="round" stroke-linecap="round"/>
  <rect x="112" y="132" width="24" height="52" rx="10" fill="#FFFFFF"/>
</g>'''),
}

for name, ((c1, c2), art) in OPTIONS.items():
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">{base(c1, c2)}{art}</svg>'
    open(f"pers-{name}.svg", "w").write(svg)
    subprocess.run(["rsvg-convert", "-w", "220", "-h", "220", f"pers-{name}.svg", "-o", f"pers-{name}.png"], check=True)
print("ok")
