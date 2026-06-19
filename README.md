# KKjorsvik OS

A personal Linux distribution — a custom, branded [Arch Linux](https://archlinux.org)
ISO built with [`archiso`](https://wiki.archlinux.org/title/Archiso). It boots to a
live environment and can install itself to disk. Built mostly to learn how a Linux
distro is actually assembled, from the boot menu down to the partition table.

## What it is

In archiso, a "distro" is just a **profile directory** that `mkarchiso` turns into a
bootable ISO. KKjorsvik OS starts from Arch's official `releng` profile and customizes:

- **Identity** — `os-release`, hostname (`kkjorsvik`), MOTD, and the boot-menu labels.
- **An installer** — `kkjorsvik-install`, a BIOS/GPT + GRUB script that lays the system
  onto a disk and gives you a persistent, branded install.

## Requirements

- An Arch Linux host (or any system with the `archiso` package) to build the ISO.
- `qemu` for local testing (hardware acceleration if `/dev/kvm` is available).
- `sudo` — `mkarchiso` needs root to set up loop devices and the squashfs.

```sh
sudo pacman -S archiso qemu-desktop
```

## Build

```sh
./build.sh
```

Produces `out/kkjorsvik-os-<date>-x86_64.iso`. The script clears the `work/`
scratch directory first, because `mkarchiso` otherwise skips already-completed
build stages on a re-run.

## Test locally

```sh
./test-qemu.sh
```

Boots the most recent ISO in QEMU (BIOS/SeaBIOS). The live system autologins to
root on tty1 and shows the KKjorsvik OS banner.

## Install to a disk

Boot the ISO (in a VM or on hardware — use **BIOS/SeaBIOS**, not UEFI), then run:

```sh
lsblk                          # confirm the target disk
kkjorsvik-install /dev/sda     # type YES, then set a root password
```

It partitions (GPT: 1 MB BIOS-boot + ext4 root), `pacstrap`s a base system,
installs GRUB, copies the KKjorsvik branding, and enables NetworkManager.
Reboot from the disk and you're in a persistent KKjorsvik OS.

> ⚠️ `kkjorsvik-install` **erases the target disk**. Only run it on a disk you mean
> to wipe (a throwaway VM is the safe way to try it).

## Repository layout

```
profile/        the archiso profile (packages, airootfs overlay, bootloader configs)
  airootfs/     files overlaid onto the live system root (branding, installer)
build.sh        wraps mkarchiso (clears work/, then builds)
test-qemu.sh    boots the latest ISO in QEMU
docs/           design specs and implementation plans
```

## Status

- ✅ Branded live ISO (boots to TTY)
- ✅ Self-installer (`kkjorsvik-install`)

### Roadmap / ideas

- Trim the package set toward a deliberately minimal base.
- Add a desktop layer (TTY → Wayland/X).
- Installer niceties: timezone, user account, and mirror prompts.

## Credits

Built on top of Arch Linux and its `archiso` `releng` profile. KKjorsvik OS is a
personal project and is not affiliated with the Arch Linux project.
