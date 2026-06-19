# KKjorsvik OS — sway Desktop Design (M3)

**Date:** 2026-06-18
**Status:** Approved (design phase)

## Goal

Give KKjorsvik OS a graphical identity: a Wayland **sway** tiling desktop, no full
DE. Built incrementally — get the window manager actually running first, then
decide what to layer on. Continues the project's "learn the layers" ethos.

## Core decisions

| Decision | Choice | Why |
|---|---|---|
| WM | **sway** (Wayland) | i3-for-Wayland: the user's i3 muscle memory and config model port directly; stable and boring-in-a-good-way for a distro. No full DE (user hasn't used one in years). |
| Config | **Clean KKjorsvik default, mirroring the user's i3 keybinds** | Distro-clean, shareable, reproducible; but day-one familiar hands. Keybinds lifted from the user's existing `~/.config/i3/config` at implementation time. |
| Delivery | **Both live ISO and installed system** (eventually) | ISO boots into sway (demo / try-before-install) and installs persist it. |
| Login | **greetd everywhere**; live auto-launches sway, installed shows **tuigreet** → sway | One consistent mechanism; no full autologin on installs (user's preference). |
| Fork-friendliness | WM is an **isolated layer** (own package group + own config dir) | A future `hyprland` branch becomes a small swap, not a rewrite. |

## Phased scope (build in this order, stop anywhere)

### Phase 1 — Minimal sway in the live ISO (the first increment)

The ONLY goal: the live ISO boots into a working, minimal KKjorsvik sway session.
Deliberately bare so we prove the foundation before adding chrome.

- Packages added to the live ISO: **sway**, **foot** (terminal), **greetd** +
  **greetd-tuigreet**, and the minimal plumbing sway needs — **polkit**, plus
  whatever sway pulls in (wlroots, seatd via greetd, mesa for software rendering).
  (Fonts come in Phase 2 with the bar that needs glyphs.)
- A minimal, well-commented `/etc/skel/.config/sway/config` with the user's i3
  keybinds, enough to: launch **foot**, move/focus/close windows, switch
  workspaces, and exit sway. No bar, no launcher yet.
- **greetd** configured so the live session auto-starts sway (no prompt on the
  live ISO).
- Verified in QEMU: ISO boots → sway session appears → can open foot → keybinds
  work → can exit.

### Phase 2 — Flesh out the bundle (decided incrementally, after Phase 1 works)

Candidate pieces, each added and tested as its own small step, chosen by the user
once sway is running: bar **waybar**, launcher **fuzzel**, notifications **mako**,
**swaylock** + **swayidle**, wallpaper **swaybg**, screenshots **grim**+**slurp**,
**wl-clipboard**, audio **pipewire**/**wireplumber**/**pipewire-pulse**,
**brightnessctl**, **xdg-desktop-portal-wlr**. Not committed yet — listed so the
config layout anticipates them.

### Phase 3 — Installer brings the desktop to disk (M3b)

- `kkjorsvik-install` gains a **regular-user step**: prompt for a username and
  password, create the user, add to `wheel`, enable `sudo` for `wheel`.
- Install the desktop package group + configs onto the target; configure greetd
  with **tuigreet** as the greeter (not autologin) → sway.
- `/etc/skel/.config/` is populated on the live ISO, so a created user inherits
  the same canonical config — no duplication between live and installed.
- Tested by installing into a Proxmox VM (display set to **virtio-gpu**) and
  logging in through tuigreet into sway.

## Architecture / key principles

- **One canonical config source.** All KKjorsvik desktop configs live under
  `profile/airootfs/etc/skel/.config/` (per-tool: `sway/`, later `waybar/`,
  `foot/`, …). New users inherit via `/etc/skel`. The live root session uses the
  same files (copied/linked from skel at build or first login) so live and
  installed never drift.
- **WM as an isolated layer.** The compositor + its config dir are separable from
  the rest, so a `hyprland` fork swaps `sway/` → `hypr/` and the package group,
  leaving terminal/bar/etc. untouched.
- **Packages grouped, not scattered.** Desktop packages are added in a clearly
  labeled block in `profile/packages.x86_64` (and the same list reused by the
  Phase 3 installer), so the desktop is easy to identify, trim, or fork.

## Testing reality (the new gotcha)

sway needs a GPU/DRM device that bare QEMU doesn't provide. So:
- `test-qemu.sh` gains a **virtio-gpu** device and more RAM, and the live session
  uses **software rendering** (`WLR_RENDERER_ALLOW_SOFTWARE=1`, llvmpipe via mesa)
  so sway runs without real GPU passthrough.
- Proxmox VMs (Phase 3) must set the **Display to virtio-gpu** for the same reason.

## Out of scope (for now)

- Hyprland (deliberately a future fork/branch).
- The Phase 2 bundle is not committed — only sway + terminal + login in Phase 1.
- Theming/wallpaper artwork, dotfile management beyond the shipped defaults.
- X11 / XWayland tuning beyond what sway provides by default.
