#!/usr/bin/env bash
# Boot the latest ISO with a persistent 25G disk attached to run a real install.
# Legacy BIOS / SeaBIOS, KVM-accelerated — the kkjorsvik-setup installer lays the
# disk out for BIOS GRUB (GPT + 1M BIOS-boot partition), which also matches
# Proxmox's default SeaBIOS machine type. Creates the disk on first run.
# Re-run any time; pass a fresh VM_DIR or delete the disk to start clean.
set -euo pipefail
cd "$(dirname "$0")"

VM_DIR="${VM_DIR:-$HOME/vm/kkjorsvik-os}"
DISK="$VM_DIR/disk.qcow2"
DISK_SIZE="${DISK_SIZE:-50G}"
RAM="${RAM:-8G}"
SMP="${SMP:-4}"

ISO="$(ls -t out/*.iso 2>/dev/null | head -1)"
if [[ -z "$ISO" ]]; then
  echo "No ISO found in ./out — run ./build.sh first." >&2
  exit 1
fi

mkdir -p "$VM_DIR"
if [[ ! -f "$DISK" ]]; then
  echo ">> Creating $DISK_SIZE disk at $DISK"
  qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"
fi

echo ">> Booting installer: $ISO (BIOS)"
echo "   disk: $DISK   ram: $RAM   vcpus: $SMP"
echo "   (the install target disk shows up as /dev/vda inside the VM)"
qemu-system-x86_64 \
  -enable-kvm -machine q35 -cpu host -smp "$SMP" -m "$RAM" \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -cdrom "$ISO" -boot d \
  -vga virtio -display gtk \
  -netdev user,id=net0 -device virtio-net,netdev=net0 \
  -name "kkjorsvik-os-install"
