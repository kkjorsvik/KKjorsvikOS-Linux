# First-boot usable desktop — design

**Date:** 2026-06-27
**Status:** Approved (brainstorm), pending implementation plan
**Repo:** kkjorsvik-os (`main`)

## Problem

After the M3.5 dev-box-provisioning split, `kkjorsvik-install` pacstraps only a
minimal floor (`base linux grub networkmanager sway foot greetd pipewire polkit`)
and copies `/etc/sway/config`. That sway config `exec`s `waybar`, `mako`, and the
polkit-gnome agent — **but none of those packages are installed at that point**;
they live in `packages.repo`, which only `kkjorsvik-setup` installs later.

Result: on first boot sway comes up, silently fails every `exec`, and the user
sees a near-black `#282828` solid background with no bar, no launcher, no
notifications. It looks like nothing loaded. The user must know to press
`Super+Return` (foot is installed) and run `kkjorsvik-setup` by hand before the
desktop becomes real.

## Goal

A fresh install should boot straight into a **complete, themed, usable desktop**
— bar, launcher, notifications, lock, wallpaper, screenshots, a daily terminal,
and a browser — **before** `kkjorsvik-setup` runs and **without** any dotfiles.
`kkjorsvik-setup` is demoted to "add my dev toolchain + apps + optional dotfiles."
Dotfiles become an opt-in customization layer on top of an already-usable system.

## Decisions (from brainstorm)

1. **First-boot scope:** full themed shell **plus** alacritty + firefox (so the
   box is browse-and-work ready the instant it boots). Only the heavy dev pile
   waits for `kkjorsvik-setup`.
2. **Wallpaper:** ship a branded Gruvbox-toned PNG in the repo.
3. **Setup discoverability:** a one-time first-login mako notification nudging the
   user to run `kkjorsvik-setup`. Setup still does **not** auto-run (it's a huge
   unprompted install).
4. **Dotfiles default:** **none**. Blank answer at the install prompt = no
   dotfiles; the sample URL is shown only as an example.

## Design

### 1. Three-tier package model

Replace the current "two manifests + a hardcoded pacstrap list" with three tiers,
each package declared exactly once (no drift between a hardcoded installer list
and the manifests — keeps "manifests are the single source of truth"):

| Tier | Manifest | Installed by | Contents |
|---|---|---|---|
| **Base** (new) | `packages.base` | installer (`pacstrap`) | OS floor + full desktop shell + alacritty + firefox + fonts |
| **Curated** (trimmed) | `packages.repo` | `kkjorsvik-setup` | dev toolchain, languages, docker/k8s, remaining GUI apps |
| **AUR** (unchanged) | `packages.aur` | `kkjorsvik-setup` | AUR pile |

`packages.base` contents = current floor:

```
base linux linux-firmware grub sudo vim networkmanager
sway foot greetd greetd-tuigreet polkit
pipewire wireplumber pipewire-pulse
```

plus the desktop shell + apps + fonts:

```
waybar swaybg swaylock swayidle fuzzel mako
grim slurp wl-clipboard brightnessctl playerctl
polkit-gnome xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-utils
pavucontrol libnotify
ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols noto-fonts noto-fonts-emoji
alacritty firefox
```

These shell/app/font packages are **removed from `packages.repo`** to avoid
duplication. (`pacman -S --needed` makes any residual overlap a no-op, so this is
about clarity, not correctness.)

Both manifests live where they do today: `profile/airootfs/usr/local/share/kkjorsvik/`.

### 2. `kkjorsvik-install` changes

- **Pacstrap from the manifest:** `pacstrap -K /mnt $(<strip> packages.base)`
  instead of the hardcoded package list. Reuse the same comment-stripping logic
  `kkjorsvik-setup` already uses (`manifest()`); factor it somewhere both can use,
  or inline an equivalent `sed` in the installer.
- **Copy the desktop configs to the target.** Today only `/etc/sway/config` +
  `start-sway` are copied. Also copy `/etc/xdg/{waybar,mako,fuzzel,foot}/` and the
  alacritty config, so the shell binaries have their themed configs (not just the
  binaries).
- **Default terminal → alacritty on the installed system only:**
  `sed -i 's/^set \$term foot/set $term alacritty/' /mnt/etc/sway/config`.
  The live ISO keeps foot (its `config.d/90-live-terminal.conf` execs `foot`
  directly, independent of `$term`). Rationale: sway substitutes `$term` at
  parse time and `include config.d/*` is at the bottom, so a drop-in can't
  override `$term` for already-parsed bindings — a target-side `sed` is the clean
  way to diverge installed vs live.
- **Dotfiles default → none:** drop the `DEFAULT_DOTFILES_URL` default. Blank
  answer = no dotfiles; show the sample URL only as an inline example in the
  prompt text.
- **Network preflight:** firefox/alacritty are not in the live ISO's package
  cache, so install-time pacstrap fetches them over the network. Add a
  connectivity check before pacstrap with a clear message. The live env runs
  NetworkManager + DHCP, so in a VM this normally just works.

### 3. Branded wallpaper

- Generate a Gruvbox-toned `wallpaper.png` (subtle gradient/geometric + a small
  "KKjorsvik OS" mark), committed at
  `profile/airootfs/usr/local/share/kkjorsvik/wallpaper.png`.
- Canonical sway config:
  `output * bg #282828 solid_color` → `output * bg /usr/local/share/kkjorsvik/wallpaper.png fill`
  (sway drives swaybg; `swaybg` is in `packages.base`).
- Installer copies the PNG to the target. Identical on live ISO and installed
  system (same absolute path).

### 4. First-login welcome notification

- New script `kkjorsvik-welcome` shipped in airootfs
  (`profile/airootfs/usr/local/bin/kkjorsvik-welcome`): waits for mako, fires a
  one-time `notify-send` ("Welcome to KKjorsvik OS — run `kkjorsvik-setup` in a
  terminal to install your dev tools, apps, and dotfiles"), then drops a
  `~/.config/kkjorsvik/.welcomed` sentinel so it never repeats.
- The **installer writes a target-only drop-in**
  `/etc/sway/config.d/20-welcome.conf` containing `exec kkjorsvik-welcome` — same
  pattern as the existing live-terminal drop-in, so it lives only on installed
  systems and the live ISO never nudges. `libnotify` (provides `notify-send`) is
  in `packages.base`.

### 5. `kkjorsvik-setup` changes

- `packages.repo` is trimmed (shell/app/font lines removed — now in base).
- Reword preamble/summary: it now installs "your dev toolchain & extras," not
  "the desktop." The post-install installer message is updated to say the desktop
  is already up and `kkjorsvik-setup` adds the dev tooling.

## Risks / edge cases

- **Install-time network** for firefox/alacritty — mitigated by the connectivity
  preflight in the installer.
- **Idempotency** — `pacman -S --needed` keeps re-running setup a no-op even with
  any package overlap.
- **Live vs installed divergence** stays funneled through the two `config.d`
  drop-ins (`90-live-terminal.conf`, target-only `20-welcome.conf`) plus the
  installer's `$term` sed and config copies. The single canonical
  `/etc/sway/config` remains the source of truth.

## Out of scope

- Auto-running `kkjorsvik-setup` on first boot (deliberately rejected — large
  unprompted install).
- A waybar "Setup" button with completion-state tracking (considered, not chosen).
- Wallpaper changes via dotfiles (users can still override later through chezmoi).
- The interactive installer (profile/disk/filesystem choice) — separate planned work.

## Verification

- `./build.sh` produces an ISO.
- Fresh install in a VM (VirtIO-GPU display) boots to a themed desktop: wallpaper,
  waybar, working launcher (fuzzel), notifications, alacritty as `Super+Return`,
  firefox launchable — all **before** running `kkjorsvik-setup`, with **no**
  dotfiles.
- The first-login welcome notification fires once and not again after dismissal.
- `kkjorsvik-setup` still completes (repo + AUR + optional dotfiles) and is a
  `--needed` no-op for base packages.
- Live ISO is unchanged: auto-foot terminal, no welcome nudge.
