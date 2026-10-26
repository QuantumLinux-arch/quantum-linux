# Quantum Linux

Una distro basada en **Arch Linux**, gratis y sin anuncios, pensada para quienes vienen de
Windows y para jugar. Escritorio propio y todo en español.

*Como Windows, pero mejor. Hecho con la comunidad.*

- Web: https://quantumlinux-arch.github.io (English: https://quantumlinux-arch.github.io/en/)
- Descargas (ISO): https://sourceforge.net/projects/quantum-linux/files/
- Repositorio de paquetes `[quantum]` (firmado): https://github.com/QuantumLinux-arch/quantum-repo
- Comunidad: https://discord.gg/qWmEb9xHkZ

> **English:** Quantum Linux is an Arch Linux based distribution for gamers and people switching
> from Windows. It ships its own desktop (Quantum Shell, written in QML for Quickshell, running on
> the Wayfire compositor), its own apps (PyQt6) and a Spanish interface. This repository contains
> the archiso profile and every package needed to build the ISO. Licensed under GPL-3.0-or-later.

Versión actual: 1.0 «Quark» (beta).

## Qué trae

- **Escritorio:** Wayfire 0.11 (Wayland) + **Quantum Shell**: barra de tareas con inicio, menú de
  apps, centro de control, panel con calendario y rendimiento, notificaciones, portapapeles,
  bloqueo, menú de apagado y la ventana «Personalizar». Decoraciones propias (– □ ×) con un
  plugin de Wayfire.
- **Como en Windows:** tecla Windows = menú, Alt + Tab, Win + flechas, Win + D, Win + E,
  Win + Shift + S, Win + V, Ctrl + Shift + Esc; los `.exe` se abren con doble clic.
- **Colores:** paleta Quantum o colores sacados del fondo (matugen), aplicados al shell, Wayfire,
  GTK, Qt y kitty por `quantum-theme`.
- **Sistema:** kernel `linux-zen`, Btrfs + Snapper + snap-pac + grub-btrfs (copia antes de cada
  actualización), zram, arranque seguro con shim firmado + llave propia (MOK).
- **Juegos:** Steam con Proton, Proton-GE, umu, MangoHud, GameMode y **Fotón** (biblioteca de
  juegos de Steam, Epic, GOG y Windows).
- **Apps propias:** Centro Quantum (bienvenida y ajustes), Quantum Store (repos de Arch, Flathub,
  AUR y Android), Fotón y «Pasar a Quantum» (trae tus cosas desde Windows).
- **Instaladores:** Calamares con diseño propio, y un instalador para Windows (beta) que prepara
  un pendrive e instala Quantum solo.

## Estructura

```
archiso/                    Perfil del ISO: paquetes, sistema en vivo, menús de arranque
branding/                   Logo original (src/) y generador de fondos e íconos
packages/
  quantum-shell/            Quantum Shell (QML para Quickshell)
  quantum-desktop/          Sesión, plantilla de Wayfire, quantum-theme, quantum-update, capturas
  quantum-wayfire-decor/    Plugin de decoraciones de Wayfire (fork del plugin decoration, MIT)
  quantum-center/           Centro Quantum (PyQt6) y modo rendimiento
  quantum-store/            Quantum Store (PyQt6 + QML)
  quantum-foton/            Fotón, biblioteca de juegos
  quantum-migrate/          «Pasar a Quantum»: app de Linux y app de Windows (Rust, egui) en windows/
  quantum-installer/        Instalación automática desde las respuestas del instalador para Windows
  quantum-secureboot/       Arranque seguro: shim firmado, MokManager y firma del kernel
  quantum-branding/         Logos, fondos, tema de SDDM, Plymouth, GRUB y fastfetch
  quantum-settings/         os-release, zram, sysctl y scripts del instalador
  quantum-calamares-config/ Configuración y diseño de Calamares
  quantum-keyring/          Llave pública de firma del repo [quantum]
  aur/                      PKGBUILD de AUR que se compilan aquí (calamares, ckbcomp, yay-bin)
scripts/                    Compilar paquetes y el ISO, probar en VM, publicar
```

## Construir el ISO

Necesitas Arch Linux (o una derivada) con `archiso`, `base-devel` y `pacman-contrib`.

```bash
scripts/build-packages.sh          # paquetes → repo/x86_64 (usa --force para recompilar todo)
sudo scripts/build-iso.sh          # ISO → out/quantumlinux-1.0-AAAA.MM.DD-x86_64.iso
scripts/test-vm.sh                 # probar el ISO en QEMU (--bios, --disk-only, --reset)
```

Recompilar un solo paquete:

```bash
cd packages/<paquete> && BUILDDIR=../../build/makepkg PKGDEST=../../repo/x86_64 makepkg -f -d --cleanbuild
```

**Firmas.** El ISO y el repo `[quantum]` oficiales van firmados con llaves que **no** están en este
repositorio (solo las públicas: `packages/quantum-keyring`). Si haces tu propia distro a partir de
Quantum, genera tus propias llaves: la de paquetes (GPG) en `quantum-keyring` y `scripts/publish-repo.sh`,
y la de arranque seguro (`scripts/sign-iso-secureboot.sh` busca la tuya en `~/.quantum-secureboot`;
si no existe, el ISO se crea sin firmar). Cambia también el nombre, el logo y el `Server` del repo
en `archiso/pacman.conf` y `quantum-settings`.

## Desarrollar el escritorio

`scripts/dev-shell.sh` abre Wayfire + Quantum Shell en una ventana, con un HOME de prueba
(`build/dev-home`) y su propio D-Bus: no toca tu sesión. El código del shell se lee directo de
`packages/quantum-shell/files/quantum`, así que basta con reiniciar `qs` para ver los cambios.

## Licencia

El código propio de Quantum Linux es software libre bajo la **GNU GPL v3 o posterior**
(`LICENSE`). Si lo usas como base, tu proyecto también debe publicar su código bajo la GPL.

Excepciones:
- `packages/quantum-wayfire-decor`: derivado del plugin `decoration` de Wayfire, licencia **MIT**.
- `packages/quantum-secureboot/files/shimx64.efi` y `mmx64.efi`: binarios firmados de shim
  (Fedora), con su propia licencia (BSD-2-Clause, ver `README-shim.txt`).
- `packages/aur/*`: PKGBUILD tomados del AUR, con la licencia de cada proyecto.
- Logos y nombre «Quantum Linux»: úsalos para referirte a este proyecto; para una distro derivada,
  usa tu propio nombre y logo.
