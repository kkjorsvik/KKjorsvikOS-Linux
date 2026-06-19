#!/usr/bin/env bash
# Boot the most recently built ISO in QEMU (BIOS/SeaBIOS, KVM-accelerated).
set -euo pipefail
cd "$(dirname "$0")"
ISO="$(ls -t out/*.iso 2>/dev/null | head -1)"
if [[ -z "$ISO" ]]; then
  echo "No ISO found in ./out — run ./build.sh first." >&2
  exit 1
fi
echo ">> Booting $ISO"
echo "   sway tip: click the window + Ctrl+Alt+G to grab the keyboard (otherwise"
echo "   your host WM eats Super). A bare sway session is a blank gray screen;"
echo "   Super+Return opens a terminal. Ctrl+Alt+G again releases the grab."
# Drop -enable-kvm if /dev/kvm isn't accessible (slower but works).
qemu-system-x86_64 -enable-kvm -m 4G -smp 2 -vga virtio -display gtk -cdrom "$ISO" -boot d
