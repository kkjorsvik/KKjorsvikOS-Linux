# KKjorsvik OS — Custom Arch ISO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a branded, bootable "KKjorsvik OS" Arch ISO that boots to a TTY (M1), then optionally installs itself onto a disk (M2).

**Architecture:** Copy Arch's official `releng` archiso profile into the repo as `profile/`, rebrand its identity files (`os-release`, hostname, MOTD) and boot menus, build it with `mkarchiso`, and smoke-test it in local QEMU before uploading to Proxmox. M2 adds a self-contained `kkjorsvik-install` script into the live system's `airootfs/` for disk installs.

**Tech Stack:** archiso 88, `mkarchiso`, bash, QEMU/KVM, GRUB (BIOS), pacstrap.

**Note on verification:** System-building has no unit-test framework, so each task's "test" is a concrete verification command with expected output. `mkarchiso` requires `sudo` — **the user runs the build and QEMU commands themselves** (per their request, for learning); agentic workers should pause and hand those commands to the user rather than running them.

**Conventions:**
- Repo root: `/home/kkjorsvik/Projects/kkjorsvik-os`
- The archiso profile lives at `profile/`
- Build artifacts go to `work/` (scratch) and `out/` (ISOs), both gitignored
- All commands below assume CWD = repo root unless stated

---

## Milestone M1 — Live ISO (tasks 1–5)

### Task 1: Scaffold the profile and repo plumbing

**Files:**
- Create: `profile/` (copied from `/usr/share/archiso/configs/releng`)
- Create: `.gitignore`
- Create: `build.sh`
- Create: `test-qemu.sh`

- [ ] **Step 1: Copy the releng profile into the repo**

Run:
```bash
cp -r /usr/share/archiso/configs/releng profile
```

- [ ] **Step 2: Verify the copy looks right**

Run:
```bash
ls profile && test -f profile/profiledef.sh && echo "OK profiledef present"
```
Expected: directory listing including `airootfs profiledef.sh packages.x86_64 efiboot grub syslinux`, then `OK profiledef present`.

- [ ] **Step 3: Create `.gitignore`**

Create `.gitignore` with exactly:
```gitignore
# archiso build artifacts
work/
out/
```

- [ ] **Step 4: Create `build.sh`**

Create `build.sh` with exactly:
```bash
#!/usr/bin/env bash
# Build the KKjorsvik OS ISO. Requires sudo (mkarchiso sets up loop devices).
set -euo pipefail
cd "$(dirname "$0")"
echo ">> Building KKjorsvik OS ISO with mkarchiso (you will be prompted for sudo)..."
sudo mkarchiso -v -w work -o out profile
echo ">> Done. ISO(s) in ./out:"
ls -lh out/*.iso
```

- [ ] **Step 5: Create `test-qemu.sh`**

Create `test-qemu.sh` with exactly:
```bash
#!/usr/bin/env bash
# Boot the most recently built ISO in QEMU (BIOS/SeaBIOS, KVM-accelerated).
set -euo pipefail
cd "$(dirname "$0")"
ISO="$(ls -t out/*.iso 2>/dev/null | head -1 || true)"
if [[ -z "$ISO" ]]; then
  echo "No ISO found in ./out — run ./build.sh first." >&2
  exit 1
fi
echo ">> Booting $ISO"
# Drop -enable-kvm if /dev/kvm isn't accessible (slower but works).
qemu-system-x86_64 -enable-kvm -m 2G -smp 2 -cdrom "$ISO" -boot d
```

- [ ] **Step 6: Make the scripts executable**

Run:
```bash
chmod +x build.sh test-qemu.sh && ls -l build.sh test-qemu.sh
```
Expected: both show `-rwxr-xr-x`.

- [ ] **Step 7: Commit**

Run:
```bash
git add -A
git commit -m "Scaffold KKjorsvik OS archiso profile from releng + build/test scripts"
```

---

### Task 2: Brand the system identity (os-release, hostname, MOTD)

**Files:**
- Create: `profile/airootfs/etc/os-release`
- Modify: `profile/airootfs/etc/hostname`
- Modify: `profile/airootfs/etc/motd`

Background: releng ships no `airootfs/etc/os-release`, so the live system falls back to `/usr/lib/os-release` ("Arch Linux"). Adding `airootfs/etc/os-release` overrides it.

- [ ] **Step 1: Create the branded `os-release`**

Create `profile/airootfs/etc/os-release` with exactly:
```
NAME="KKjorsvik OS"
PRETTY_NAME="KKjorsvik OS"
ID=kkjorsvik
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;120;170;255"
HOME_URL="https://github.com/kkjorsvik/kkjorsvik-os"
LOGO=archlinux-logo
```

- [ ] **Step 2: Set the hostname**

Overwrite `profile/airootfs/etc/hostname` so its entire contents are exactly:
```
kkjorsvik
```

- [ ] **Step 3: Replace the MOTD with a KKjorsvik banner**

Overwrite `profile/airootfs/etc/motd` so its entire contents are exactly:
```

   __ __ __ __  _                  _ _      ___  ___
  |  |  |  |  |/ /_ ___  _ _ ___ _(_) |_   / _ \/ __|
  |    <|    <|  '_/ _ \| '_(_-< V / |  _| | (_) \__ \
  |_|\_|_|\_|_|_| \___/|_| /__/\_/|_|\__|  \___/|___/

  Welcome to KKjorsvik OS (live).
  A personal Arch-based distro, built for learning.

  - Network via DHCP should work automatically; check with: ip a
  - You are root on tty1. Have fun.

```

- [ ] **Step 4: Verify the three files**

Run:
```bash
grep PRETTY_NAME profile/airootfs/etc/os-release
cat profile/airootfs/etc/hostname
head -1 profile/airootfs/etc/motd >/dev/null && echo "motd OK"
```
Expected: `PRETTY_NAME="KKjorsvik OS"`, then `kkjorsvik`, then `motd OK`.

- [ ] **Step 5: Commit**

Run:
```bash
git add -A
git commit -m "Brand system identity: os-release, hostname, MOTD"
```

---

### Task 3: Brand the boot menus and profile metadata

**Files:**
- Modify: `profile/profiledef.sh`
- Modify: `profile/syslinux/archiso_head.cfg`
- Modify: `profile/syslinux/archiso_sys-linux.cfg`
- Modify: `profile/efiboot/loader/entries/01-archiso-linux.conf`
- Modify: `profile/grub/grub.cfg`

- [ ] **Step 1: Update `profiledef.sh` identity fields**

In `profile/profiledef.sh`, change these four lines:

From:
```bash
iso_name="archlinux"
iso_label="ARCH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Arch Linux <https://archlinux.org>"
iso_application="Arch Linux Live/Rescue DVD"
```
To:
```bash
iso_name="kkjorsvik-os"
iso_label="KKJORSVIK_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="KKjorsvik <https://github.com/kkjorsvik/kkjorsvik-os>"
iso_application="KKjorsvik OS Live"
```
**Leave `install_dir="arch"` unchanged** — it is an internal on-ISO path, not user-visible, and changing it only risks breakage.

- [ ] **Step 2: Update the syslinux menu title**

In `profile/syslinux/archiso_head.cfg`, change the line:
```
MENU TITLE Arch Linux
```
To:
```
MENU TITLE KKjorsvik OS
```

- [ ] **Step 3: Update the syslinux boot entry labels**

In `profile/syslinux/archiso_sys-linux.cfg`, change both `MENU LABEL` lines:

From:
```
MENU LABEL Arch Linux install medium (%ARCH%, BIOS)
```
To:
```
MENU LABEL KKjorsvik OS (%ARCH%, BIOS)
```
And from:
```
MENU LABEL Arch Linux install medium (%ARCH%, BIOS) with ^speech
```
To:
```
MENU LABEL KKjorsvik OS (%ARCH%, BIOS) with ^speech
```

- [ ] **Step 4: Update the UEFI systemd-boot entry title**

In `profile/efiboot/loader/entries/01-archiso-linux.conf`, change:
```
title    Arch Linux install medium (%ARCH%, UEFI)
```
To:
```
title    KKjorsvik OS (%ARCH%, UEFI)
```

- [ ] **Step 5: Update the GRUB menu entry title**

In `profile/grub/grub.cfg`, change the first menuentry title from:
```
menuentry "Arch Linux install medium (%ARCH%, ${archiso_platform})" --class arch --class gnu-linux --class gnu --class os --id 'archlinux' {
```
To:
```
menuentry "KKjorsvik OS (%ARCH%, ${archiso_platform})" --class arch --class gnu-linux --class gnu --class os --id 'archlinux' {
```
(Keep `--id 'archlinux'` unchanged — internal IDs are referenced elsewhere in the file.)

- [ ] **Step 6: Verify no stray "Arch Linux install medium" labels remain in menus**

Run:
```bash
grep -rn "KKjorsvik OS" profile/syslinux profile/efiboot profile/grub
grep -rn "install medium" profile/syslinux profile/efiboot profile/grub || echo "no stray labels"
grep '^iso_name' profile/profiledef.sh
```
Expected: KKjorsvik OS labels listed; `no stray labels`; `iso_name="kkjorsvik-os"`.

- [ ] **Step 7: Commit**

Run:
```bash
git add -A
git commit -m "Brand boot menus (syslinux/UEFI/GRUB) and ISO metadata"
```

---

### Task 4: Build the M1 ISO (USER RUNS THIS)

**Files:** none modified — this produces `out/kkjorsvik-os-*.iso`.

- [ ] **Step 1: Run the build**

User runs:
```bash
./build.sh
```
This prompts for sudo and takes several minutes (downloads packages, builds squashfs). Expected tail output: `>> Done. ISO(s) in ./out:` followed by an `ls -lh` line showing `out/kkjorsvik-os-<date>-x86_64.iso`.

- [ ] **Step 2: Verify the ISO exists and is branded**

Run:
```bash
ls -lh out/*.iso
file out/*.iso
```
Expected: a multi-hundred-MB file; `file` reports an ISO 9660 image with the `KKJORSVIK_<yyyymm>` volume label.

- [ ] **Step 3: Commit the build wiring note (no artifacts — they're gitignored)**

Run:
```bash
git status --short
```
Expected: clean (or only untracked `work/`/`out/`, which are ignored). No commit needed if nothing changed.

---

### Task 5: Smoke-test M1 in QEMU (USER RUNS THIS)

**Files:** none.

- [ ] **Step 1: Boot the ISO locally**

User runs:
```bash
./test-qemu.sh
```
A QEMU window opens showing the boot menu titled **KKjorsvik OS**.

- [ ] **Step 2: Verify the live system branding**

In the booted QEMU guest (it autologins to root on tty1), the MOTD banner should display the KKjorsvik OS welcome. Then run inside the guest:
```bash
hostname
grep PRETTY_NAME /etc/os-release
```
Expected: `kkjorsvik` and `PRETTY_NAME="KKjorsvik OS"`.

- [ ] **Step 3: Shut down the guest**

In the guest run `poweroff`, or close the QEMU window.

**🎉 M1 complete** — you have a branded, bootable KKjorsvik OS live ISO. Optional: upload `out/kkjorsvik-os-*.iso` to Proxmox (Datacenter → your node → local storage → ISO Images → Upload) and boot a VM from it to confirm on the "real" hypervisor.

**STOP/CHECKPOINT:** This is a natural stopping point. Continue to M2 only if energy holds.

---

## Milestone M2 — Self-installing ISO (tasks 6–7, stretch)

### Task 6: Add the `kkjorsvik-install` script to the live system

**Files:**
- Create: `profile/airootfs/usr/local/bin/kkjorsvik-install`
- Modify: `profile/profiledef.sh` (add file permission entry)

Design: a BIOS/GPT installer using GRUB (`i386-pc`). BIOS boot matches both QEMU's default SeaBIOS and Proxmox's default VM BIOS, so no UEFI/OVMF setup is needed. It installs a minimal base + NetworkManager and copies the live branding to the target.

- [ ] **Step 1: Create the installer script**

Create `profile/airootfs/usr/local/bin/kkjorsvik-install` with exactly:
```bash
#!/usr/bin/env bash
# KKjorsvik OS installer — BIOS/GPT + GRUB. Run as root from the live ISO.
# WARNING: erases the target disk.
set -euo pipefail

DISK="${1:-/dev/sda}"

echo "=== KKjorsvik OS installer ==="
echo "Target disk: $DISK"
lsblk "$DISK"
read -rp "This will ERASE $DISK. Type YES to continue: " confirm
[[ "$confirm" == "YES" ]] || { echo "Aborted."; exit 1; }

echo ">> Partitioning $DISK (GPT: 1M BIOS-boot + rest root)..."
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1M  -t1:ef02 -c1:"BIOS boot" "$DISK"
sgdisk -n2:0:0    -t2:8300 -c2:"KKjorsvik root" "$DISK"
partprobe "$DISK"

# Partition node naming: /dev/sda2, but /dev/nvme0n1p2.
if [[ "$DISK" == *nvme* ]]; then ROOT="${DISK}p2"; else ROOT="${DISK}2"; fi

echo ">> Formatting $ROOT as ext4..."
mkfs.ext4 -F "$ROOT"
mount "$ROOT" /mnt

echo ">> Installing base system with pacstrap..."
pacstrap -K /mnt base linux linux-firmware grub vim sudo networkmanager

echo ">> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo ">> Applying KKjorsvik branding to the installed system..."
cp /etc/os-release /mnt/etc/os-release
echo kkjorsvik > /mnt/etc/hostname

# Unquoted heredoc: $DISK below expands HERE (in this script) before being
# handed to the chroot shell. No other $-expansions exist in the body.
echo ">> Configuring the installed system in chroot..."
arch-chroot /mnt /bin/bash -euo pipefail <<CHROOT
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc || true
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
systemctl enable NetworkManager
grub-install --target=i386-pc "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg
echo "Set the root password for your new KKjorsvik OS install:"
passwd
CHROOT

echo ">> Unmounting..."
umount -R /mnt
echo "=== Done. Remove the ISO and reboot into KKjorsvik OS. ==="
```

- [ ] **Step 2: Mark the script executable in the ISO**

In `profile/profiledef.sh`, add one entry to the `file_permissions` array (inside the existing parentheses, alongside the other entries):
```bash
  ["/usr/local/bin/kkjorsvik-install"]="0:0:755"
```

- [ ] **Step 3: Verify script and permission wiring**

Run:
```bash
bash -n profile/airootfs/usr/local/bin/kkjorsvik-install && echo "syntax OK"
grep "kkjorsvik-install" profile/profiledef.sh
grep -n 'arch-chroot /mnt' profile/airootfs/usr/local/bin/kkjorsvik-install
```
Expected: `syntax OK`; the file_permissions line; and the chroot line reading `arch-chroot /mnt /bin/bash -euo pipefail <<CHROOT`.

- [ ] **Step 4: Rebuild the ISO (USER RUNS THIS)**

User runs:
```bash
./build.sh
```
Expected: a fresh `out/kkjorsvik-os-*.iso` containing the installer.

- [ ] **Step 5: Commit**

Run:
```bash
git add -A
git commit -m "M2: add kkjorsvik-install disk installer to the live ISO"
```

---

### Task 7: Test the install end-to-end in Proxmox (USER RUNS THIS)

**Files:** none.

- [ ] **Step 1: Create a Proxmox test VM**

In the Proxmox web UI: upload the new ISO, then create a VM with **BIOS = SeaBIOS (default)**, a single virtual disk (e.g. 16 GB, which appears as `/dev/sda`), and attach the ISO as a CD-ROM. Set boot order: CD-ROM first.

- [ ] **Step 2: Boot the live ISO and run the installer**

Boot the VM (it lands at the KKjorsvik OS live TTY), then run:
```bash
kkjorsvik-install /dev/sda
```
Type `YES` when prompted, and set a root password when asked. Expected final line: `=== Done. Remove the ISO and reboot into KKjorsvik OS. ===`.

- [ ] **Step 3: Reboot into the installed system**

In the Proxmox VM, set boot order back to the hard disk (or detach the ISO), then reboot. Expected: the VM boots from disk through GRUB into a persistent KKjorsvik OS, presenting a login prompt. Log in as root with the password you set.

- [ ] **Step 4: Verify the persistent install**

In the installed system run:
```bash
hostname
grep PRETTY_NAME /etc/os-release
systemctl is-enabled NetworkManager
```
Expected: `kkjorsvik`; `PRETTY_NAME="KKjorsvik OS"`; `enabled`.

**🎉 M2 complete** — KKjorsvik OS installs to disk and boots persistently.

---

## Future ideas (out of scope for this plan)

- Trim `packages.x86_64` toward a deliberately minimal set (learning exercise).
- Add a desktop layer (TTY → Wayland/X) as a follow-up spec.
- Network/installer niceties: timezone prompt, user account creation, mirror selection.
