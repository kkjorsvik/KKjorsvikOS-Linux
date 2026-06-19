# KKjorsvik OS — sway Desktop Phase 2 + Phase 3 Design

**Date:** 2026-06-19
**Status:** Approved (design phase)
**Builds on:** `2026-06-18-sway-desktop-design.md` (Phase 1 shipped a minimal sway live ISO).

## Goal

Turn the bare Phase 1 sway session into a real, themed daily-driver desktop
(Phase 2), then make the installer put that desktop — and a real user account —
onto disk (Phase 3). Both phases targeted for one session.

## Decisions locked

- **Bundle scope:** sway shell **plus** the maintainer's daily apps (chromium, thunar).
- **Theme:** Dracula (matches the maintainer's i3) across waybar/foot/fuzzel/mako/sway
  borders, with a solid Dracula background (`#282a36`) via swaybg. No image asset.
- **Single canonical config** continues: system-wide locations inherited by the live
  root session now and installed users later (`/etc/sway/config`, `/etc/xdg/<tool>/`).
- **Installed login:** greetd + **tuigreet** (a real prompt, not autologin) → sway.

## Phase 2 — themed desktop bundle (live ISO)

### Packages (append to `profile/packages.x86_64`)
`waybar fuzzel mako swaylock swayidle swaybg grim slurp wl-clipboard pipewire
wireplumber pipewire-pulse pavucontrol brightnessctl xdg-desktop-portal-wlr
xdg-desktop-portal-gtk ttf-jetbrains-mono-nerd polkit-gnome gvfs chromium thunar`
(all verified present in the official repos).

### Configs (canonical, system-wide)
- **`/etc/sway/config`** (update the Phase 1 file):
  - Activate the previously-commented binds: `$mod+d`→`fuzzel`, `Print`→`grim -g "$(slurp)" - | wl-copy` (+ a save variant), `$mod+Shift+x`→`swaylock -c 282a36`, media keys→`wpctl`, `$mod+b`→`chromium`, `$mod+Shift+f`→`thunar`.
  - Autostart via `exec`: `waybar`, `mako`, `swayidle -w timeout 600 'swaylock -f -c 282a36'`, `/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1`.
  - Background: `output * bg #282a36 solid_color`.
  - Dracula window-border colors (`client.focused` etc.) and `font pango:JetBrainsMono Nerd Font 10`.
  - Remove `xwayland disable` only if needed by chromium; keep disabled (chromium runs native Wayland via `--ozone-platform-hint=auto`). Decision: **keep `xwayland disable`** for now; revisit if an app needs X.
- **`/etc/xdg/waybar/config`** + **`/etc/xdg/waybar/style.css`** — modules: `sway/workspaces`, `sway/mode` (left); `clock` (center); `pulseaudio`, `network`, `cpu`, `memory`, `tray` (right). Dracula style, Nerd Font glyphs.
- **`/etc/xdg/foot/foot.ini`** — Dracula palette + `font=JetBrainsMono Nerd Font:size=11`.
- **`/etc/xdg/fuzzel/fuzzel.ini`** — Dracula colors + the Nerd Font.
- **`/etc/xdg/mako/config`** — Dracula colors.

### Verify (QEMU)
Rebuild → boot (grab keyboard with Ctrl+Alt+G) → waybar visible at top, Dracula
background (not gray), `$mod+d` opens fuzzel, `$mod+Return` opens themed foot,
`$mod+Shift+x` locks, screenshots work. (Audio likely has no sink in QEMU — fine.)

## Phase 3 — installer brings the desktop + a user to disk

Extend `profile/airootfs/usr/local/bin/kkjorsvik-install`:
- **User account:** prompt for a username; in chroot `useradd -m -G wheel "$USER"`,
  set its password (`passwd "$USER"`), and enable sudo for the wheel group
  (drop `%wheel ALL=(ALL:ALL) ALL` into `/etc/sudoers.d/10-wheel`, mode 0440).
- **Desktop packages:** extend the `pacstrap` list with the full Phase 2 bundle
  (sway, foot, greetd, greetd-tuigreet, polkit + the Phase 2 packages, chromium, thunar).
- **Copy canonical configs onto the target** (the live env already holds them — DRY):
  `cp /usr/local/bin/start-sway /mnt/usr/local/bin/`, `cp /etc/sway/config /mnt/etc/sway/`,
  and `cp -rT /etc/xdg/<tool> /mnt/etc/xdg/<tool>` for waybar/foot/fuzzel/mako. `chmod 755`
  the wrapper.
- **Login (installed):** write `/mnt/etc/greetd/config.toml` using tuigreet:
  `command = "tuigreet --time --remember --cmd /usr/local/bin/start-sway"`, `user = "greetd"`.
  Enable greetd and set the default target to graphical in the chroot
  (`systemctl enable greetd`; `systemctl set-default graphical.target`).

### Verify (Proxmox)
Install into a Proxmox VM with **Display = virtio-gpu** → reboot → **tuigreet**
login prompt → log in as the new user → themed sway desktop with waybar.

## Architecture / principles

- WM stays an isolated layer (sway config + package group separable) so a future
  Hyprland fork is a small swap.
- Live ISO and installed system share one config source; the installer copies the
  live env's configs rather than duplicating them in the repo.
- greetd config differs by role: live = autologin root → sway (Phase 1); installed =
  tuigreet → sway as the user (Phase 3).

## Out of scope
- Image wallpaper/artwork (solid Dracula color only for now).
- Per-user dotfile management beyond shipped defaults.
- Multi-monitor / laptop-specific tuning.
- Hyprland (still a future fork).

## Execution
Two implementation plans run back-to-back on branch `sway-desktop-phase2-3`:
Phase 2 (themed live desktop) then Phase 3 (installer). One PR at the end.
