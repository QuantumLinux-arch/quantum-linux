#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="quantumlinux"
iso_label="QUANTUM_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Quantum Linux <https://github.com/quantum-linux>"
iso_application="Quantum Linux Live"
iso_version="1.0-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="quantum"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers.d/10-liveuser"]="0:0:440"
  ["/home/liveuser/"]="1000:1000:755"
)
