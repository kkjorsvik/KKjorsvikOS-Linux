# KKjorsvik OS — Custom Arch ISO Design

**Date:** 2026-06-18
**Status:** Approved (design phase)

## Goal

A personal Linux distribution built as a custom Arch ISO, primarily as a vehicle
for learning Linux at a deeper level. Fun and exploration are first-class goals;
shipping a polished product is not. It is OK to stop at any milestone.

## Core decisions

| Decision | Choice | Why |
|---|---|---|
| Depth | Custom Arch ISO via `archiso` | "Real distro" feel, testable tonight, teaches boot/initramfs/packaging without weeks of compiling. |
| Desktop | Minimal / TTY first | See every layer; add a GUI later as a conscious step. |
| First milestone | Live ISO now, installer tonight if it's flowing | Incremental — a win either way. |
| Base profile | Copy official `releng`, trim toward minimal | Boots reliably to an autologin TTY *with networking*; night one is "rebrand and boot," not "debug no-network." (Alternative: start from bare `baseline` — more hardcore, deferred.) |

## Mental model

In archiso, a "distro" is a **profile directory** that `mkarchiso` turns into a
bootable ISO. Key pieces:

- `packages.x86_64` — packages baked into the ISO.
- `airootfs/` — overlaid as the live system root (`/`). **The distro's identity
  lives here**: `airootfs/etc/os-release`, `/etc/motd`, `/etc/hostname`,
  autologin config, etc.
- `profiledef.sh` — ISO name, label, build settings, file permissions.
- bootloader configs (`efiboot/`, `syslinux/`, `grub/`) — the boot menu branding.

Making the distro = curating a package list + writing files into `airootfs/`.

## Environment (verified 2026-06-18)

- Arch Linux host, `archiso 88` installed, `mkarchiso` available.
- `/dev/kvm` present → **local QEMU is the dev loop** (instant boot test).
- ~334 GB free on `/home`.
- Proxmox is a separate host with no local `qm` CLI → ISO upload to Proxmox is a
  manual web-UI step, done only at milestone checkpoints, not every build.

## Milestones

- **M0 — Scaffold & brand:** copy `releng` into the repo as the `kkjorsvik-os`
  profile; rebrand `os-release`, hostname, MOTD, and boot-menu entries to
  KKjorsvik OS.
- **M1 — Live ISO (tonight's win):** `mkarchiso` build → boot the `.iso` locally
  in QEMU → confirm it boots to a TTY announcing KKjorsvik OS. Optionally upload
  to Proxmox.
- **M2 — Installer (only if flowing):** add a guided install script into
  `airootfs/` that partitions a disk, `pacstrap`s a base system, installs a
  bootloader, and produces a persistent install. Test by installing into a
  Proxmox VM and rebooting into it.

## Repository layout

Everything lives under `kkjorsvik-os/` in git so the distro is reproducible from
a clone:

- the `kkjorsvik-os` archiso profile
- a build script wrapping `mkarchiso`
- a local QEMU test helper
- docs

## Testing strategy

- **Dev loop:** `qemu-system-x86_64 -enable-kvm -cdrom <iso>` — fast, local.
- **Checkpoint:** upload to Proxmox, boot a VM (and, for M2, install to its
  virtual disk and reboot into the installed system).

## Out of scope (for now)

- Desktop environment / GUI (deferred until after TTY plumbing).
- Custom package repository / signed packages.
- Distribution to anyone but the author.
