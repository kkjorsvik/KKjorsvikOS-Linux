#!/usr/bin/env bash
# Boot the INSTALLED system from its disk (no ISO) to test the real first-boot
# experience. Legacy BIOS / SeaBIOS, KVM-accelerated — matches both how the
# installer lays out the disk (GPT + 1M BIOS-boot partition, GRUB for i386-pc)
# and Proxmox's default SeaBIOS machine type. Run ./test-vm-install.sh first.
set -euo pipefail
cd "$(dirname "$0")"

VM_DIR="${VM_DIR:-$HOME/vm/kkjorsvik-os}"
DISK="$VM_DIR/disk.qcow2"
RAM="${RAM:-8G}"
SMP="${SMP:-4}"

if [[ ! -f "$DISK" ]]; then
  echo "No disk at $DISK — run ./test-vm-install.sh first." >&2
  exit 1
fi

echo ">> Booting installed system from $DISK (BIOS)"
echo "   ram: $RAM   vcpus: $SMP"
qemu-system-x86_64 \
  -enable-kvm -machine q35 -cpu host -smp "$SMP" -m "$RAM" \
  -drive file="$DISK",if=virtio,format=qcow2 \
  -boot c \
  -vga virtio -display gtk \
  -netdev user,id=net0 -device virtio-net,netdev=net0 \
  -name "kkjorsvik-os"
