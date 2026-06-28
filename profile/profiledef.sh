#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="kkjorsvik-os"
iso_label="KKJORSVIK_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="KKjorsvik <https://github.com/kkjorsvik/kkjorsvik-os>"
iso_application="KKjorsvik OS Live"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/kkjorsvik-install"]="0:0:755"
  ["/usr/local/bin/kkjorsvik-setup"]="0:0:755"
  ["/usr/local/bin/kkjorsvik-welcome"]="0:0:755"
  ["/usr/local/bin/start-sway"]="0:0:755"
)
