# First-boot usable desktop — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a fresh KKjorsvik OS install boot straight into a complete, themed, usable desktop (bar, launcher, notifications, lock, wallpaper, alacritty, firefox) before `kkjorsvik-setup` runs and without any dotfiles.

**Architecture:** Promote the desktop shell + alacritty + firefox + fonts from `kkjorsvik-setup` into the installer via a new `packages.base` manifest that the installer pacstraps. Ship a branded wallpaper and a system-wide Gruvbox alacritty config. Add a one-time first-login notification nudging the user to run `kkjorsvik-setup`. Default dotfiles to none. Live-vs-installed divergence stays funneled through two `config.d` drop-ins plus a target-side `$term` sed.

**Tech Stack:** archiso, bash, sway/wlroots config, TOML (alacritty), ImageMagick (wallpaper), pacstrap.

**Verification model:** This is a bash + config project with no unit-test harness. "Tests" are: `bash -n` syntax checks, `shellcheck`, JSON/TOML parse checks, and `grep` content assertions — all runnable on the host. The final end-to-end check is a real ISO build + VM install, which is **handed to the user** (their standing preference is to run sudo/build/QEMU commands themselves).

---

## File structure

| File | Action | Responsibility |
|---|---|---|
| `profile/airootfs/usr/local/share/kkjorsvik/packages.base` | **Create** | Single source of truth for what the installer pacstraps: OS floor + desktop shell + alacritty + firefox + fonts |
| `profile/airootfs/usr/local/share/kkjorsvik/packages.repo` | Modify | Curated dev pile; shell/app/font packages removed (now in base) |
| `profile/airootfs/etc/xdg/alacritty/alacritty.toml` | **Create** | System-wide Gruvbox theme for the daily terminal (usable without dotfiles) |
| `profile/airootfs/usr/local/share/kkjorsvik/wallpaper.png` | **Create** | Branded default wallpaper |
| `profile/airootfs/etc/sway/config` | Modify | Point `output bg` at the wallpaper image |
| `profile/airootfs/usr/local/bin/kkjorsvik-welcome` | **Create** | One-time first-login nudge to run `kkjorsvik-setup` |
| `profile/airootfs/usr/local/bin/kkjorsvik-install` | Modify | Pacstrap from `packages.base`, copy desktop configs + wallpaper, repoint `$term`, default dotfiles none, network preflight, write welcome drop-in |
| `profile/airootfs/usr/local/bin/kkjorsvik-setup` | Modify | Reword preamble/summary (it now adds dev tooling, not the desktop) |

---

## Task 1: Create the `packages.base` manifest

**Files:**
- Create: `profile/airootfs/usr/local/share/kkjorsvik/packages.base`

- [ ] **Step 1: Write the manifest**

```
# KKjorsvik OS — base manifest: the bootable, usable desktop.
# Installed by kkjorsvik-install via: pacstrap -K /mnt <this list>
# Everything here is present on FIRST BOOT, before kkjorsvik-setup and before any
# dotfiles. The curated dev toolchain lives in packages.repo / packages.aur.
# One package per line. '#' comments and blank lines are ignored.

# === OS floor ===
base
linux
linux-firmware
grub
sudo
vim
networkmanager

# === Login + session ===
greetd
greetd-tuigreet
polkit
polkit-gnome

# === Sway desktop shell ===
sway
swaybg
swaylock
swayidle
waybar
fuzzel
mako
foot          # guaranteed native-Wayland fallback terminal
grim
slurp
wl-clipboard
brightnessctl
playerctl
libnotify     # provides notify-send for the first-login welcome

# === Desktop portals ===
xdg-desktop-portal-wlr
xdg-desktop-portal-gtk
xdg-utils

# === Audio (base subset; extras live in packages.repo) ===
pipewire
wireplumber
pipewire-pulse
pavucontrol

# === Fonts (shell needs these to render correctly) ===
ttf-jetbrains-mono-nerd
ttf-nerd-fonts-symbols
noto-fonts
noto-fonts-emoji

# === Default terminal + browser (usable out of the box) ===
alacritty
firefox
```

- [ ] **Step 2: Verify the strip logic produces a clean package list**

Run:
```bash
cd ~/Projects/kkjorsvik-os
sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' -e '/^$/d' \
  profile/airootfs/usr/local/share/kkjorsvik/packages.base
```
Expected: 35 bare package names, one per line, no comments, no blank lines, no inline `#` fragments (e.g. `foot` not `foot          # ...`).

- [ ] **Step 3: Commit**

```bash
git add profile/airootfs/usr/local/share/kkjorsvik/packages.base
git commit -m "feat: add packages.base manifest (bootable usable desktop)"
```

---

## Task 2: Trim shell/app/font packages out of `packages.repo`

**Files:**
- Modify: `profile/airootfs/usr/local/share/kkjorsvik/packages.repo`

Remove every package now declared in `packages.base` so each package is declared once. Replace the file's contents with the trimmed version below.

- [ ] **Step 1: Write the trimmed manifest**

Full new contents of `packages.repo`:

```
# KKjorsvik OS — official-repo package manifest (curated dev pile).
# Installed by kkjorsvik-setup via: pacman -S --needed -
# The bootable desktop shell + alacritty + firefox + base fonts live in
# packages.base (installed by kkjorsvik-install). Do NOT duplicate them here.
# One package per line. '#' comments and blank lines are ignored.

# === Core CLI & system ===
base-devel
git
fish
neovim
tmux
fastfetch
btop
fd
fzf
ripgrep
tree
ranger
less
plocate
lsof
net-tools
bind
usbutils
smartmontools
rsync
rclone
sshfs
openssh
wget
man-db
man-pages
zip
unzip

# === Git & dev tooling ===
git-delta
lazygit
lazydocker
github-cli
gitleaks
git-filter-repo
pre-commit
glow
tldr
cloc
chezmoi

# === Languages & runtimes ===
go
go-task
golangci-lint
nodejs
npm
pnpm
python-pip
python-pipx
python-virtualenv
uv
mise
elixir
erlang
php
php-fpm
php-gd
php-pgsql
php-sqlite
composer
maven
gradle
julia
hugo
protobuf

# === Cloud / DevOps ===
docker
docker-compose
kubectl
opentofu
aws-cli-v2
tailscale
nginx
postgresql
mkcert
ollama
woodpecker-cli

# === Desktop extras (shell itself is in packages.base) ===
nwg-look
gvfs
pipewire-alsa
pipewire-jack
gst-plugin-pipewire

# === Bluetooth ===
bluez
bluez-utils
blueman

# === Printing & scanning ===
cups
cups-pdf
gutenprint
sane
sane-airscan
simple-scan

# === Hardware ===
fprintd
solaar

# === GUI apps (alacritty + firefox are in packages.base) ===
zed
code
chromium
thunar
thunar-archive-plugin
thunar-volman
tumbler
file-roller
okular
gwenview
obsidian
discord
lutris
flameshot

# === Terminal AI / CLIs ===
gemini-cli
opencode

# === Fonts (base fonts are in packages.base) ===
ttf-firacode-nerd
ttf-nerd-fonts-symbols-mono
woff2-font-awesome

# === Distro-building (optional — keep if you build kkjorsvik-os on this box) ===
archiso
qemu-full
```

> Note: `vim` was also dropped from `packages.repo` — it's in `packages.base` (and `neovim` is the curated editor). `foot` likewise moved to base.

- [ ] **Step 2: Verify no package is declared in both manifests**

Run:
```bash
cd ~/Projects/kkjorsvik-os
SHARE=profile/airootfs/usr/local/share/kkjorsvik
strip() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' -e '/^$/d' "$1"; }
comm -12 <(strip $SHARE/packages.base | sort) <(strip $SHARE/packages.repo | sort)
```
Expected: **no output** (empty intersection — nothing declared twice).

- [ ] **Step 3: Commit**

```bash
git add profile/airootfs/usr/local/share/kkjorsvik/packages.repo
git commit -m "refactor: trim shell/app/font packages from packages.repo (now in base)"
```

---

## Task 3: Ship a system-wide Gruvbox alacritty config

**Files:**
- Create: `profile/airootfs/etc/xdg/alacritty/alacritty.toml`

Alacritty reads `$XDG_CONFIG_DIRS/alacritty/alacritty.toml` (i.e. `/etc/xdg/...`) when there's no per-user config, so this themes the daily terminal before any dotfiles. Palette matches `foot.ini`.

- [ ] **Step 1: Write the config**

```toml
# KKjorsvik OS — system-wide alacritty theme (Gruvbox Material).
# Per-user ~/.config/alacritty/alacritty.toml (e.g. from dotfiles) overrides this.

[font]
size = 11.0

[font.normal]
family = "JetBrainsMono Nerd Font"

[colors.primary]
background = "#282828"
foreground = "#e0cfa0"

[colors.normal]
black   = "#282828"
red     = "#ea6962"
green   = "#a9b665"
yellow  = "#d8a657"
blue    = "#7daea3"
magenta = "#d3869b"
cyan    = "#89b482"
white   = "#d4be98"

[colors.bright]
black   = "#928374"
red     = "#fb4934"
green   = "#bcc44a"
yellow  = "#ecb142"
blue    = "#8ec0a8"
magenta = "#e08bab"
cyan    = "#9bcb72"
white   = "#e0cfa0"
```

- [ ] **Step 2: Verify it parses as TOML**

Run:
```bash
cd ~/Projects/kkjorsvik-os
python -c "import tomllib,sys; tomllib.load(open('profile/airootfs/etc/xdg/alacritty/alacritty.toml','rb')); print('OK')"
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add profile/airootfs/etc/xdg/alacritty/alacritty.toml
git commit -m "feat: system-wide Gruvbox alacritty config"
```

---

## Task 4: Generate the branded wallpaper and point sway at it

**Files:**
- Create: `profile/airootfs/usr/local/share/kkjorsvik/wallpaper.png`
- Modify: `profile/airootfs/etc/sway/config:23`

- [ ] **Step 1: Generate the wallpaper PNG**

Primary (ImageMagick v7):
```bash
cd ~/Projects/kkjorsvik-os
magick -size 2560x1440 gradient:'#32302f-#1d2021' \
  -gravity south -fill '#504945' -pointsize 34 \
  -annotate +0+90 'KKjorsvik OS' \
  profile/airootfs/usr/local/share/kkjorsvik/wallpaper.png
```

Fallback if `magick` is unavailable (Pillow):
```bash
python - <<'PY'
from PIL import Image, ImageDraw, ImageFont
w,h=2560,1440
top=(0x32,0x30,0x2f); bot=(0x1d,0x20,0x21)
# Build a 1px-wide vertical gradient, then scale to full width (fast).
col=Image.new("RGB",(1,h))
for y in range(h):
    t=y/(h-1)
    col.putpixel((0,y),tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3)))
img=col.resize((w,h))
d=ImageDraw.Draw(img)
try: f=ImageFont.truetype("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf",34)
except Exception: f=ImageFont.load_default()
txt="KKjorsvik OS"
bb=d.textbbox((0,0),txt,font=f)
d.text(((w-(bb[2]-bb[0]))//2, h-150), txt, fill=(0x50,0x49,0x45), font=f)
img.save("profile/airootfs/usr/local/share/kkjorsvik/wallpaper.png")
PY
```

- [ ] **Step 2: Verify the image is a valid PNG of the right size**

Run:
```bash
cd ~/Projects/kkjorsvik-os
file profile/airootfs/usr/local/share/kkjorsvik/wallpaper.png
```
Expected: `PNG image data, 2560 x 1440` (8-bit/color RGB).

- [ ] **Step 3: Point sway at the wallpaper**

In `profile/airootfs/etc/sway/config`, replace line 23:
```
output * bg #282828 solid_color
```
with:
```
output * bg /usr/local/share/kkjorsvik/wallpaper.png fill
```

- [ ] **Step 4: Verify the sway config references the image and no longer uses solid_color**

Run:
```bash
cd ~/Projects/kkjorsvik-os
grep -n 'output \* bg' profile/airootfs/etc/sway/config
```
Expected: one line, `output * bg /usr/local/share/kkjorsvik/wallpaper.png fill` (no `solid_color`).

- [ ] **Step 5: Commit**

```bash
git add profile/airootfs/usr/local/share/kkjorsvik/wallpaper.png profile/airootfs/etc/sway/config
git commit -m "feat: branded wallpaper + point sway output bg at it"
```

---

## Task 5: First-login welcome script

**Files:**
- Create: `profile/airootfs/usr/local/bin/kkjorsvik-welcome`

- [ ] **Step 1: Write the script**

```sh
#!/bin/sh
# kkjorsvik-welcome — one-time first-login nudge to run kkjorsvik-setup.
# Fires once per user (sentinel under ~/.config/kkjorsvik), then never again.
# Installed-system only: kkjorsvik-install wires it via /etc/sway/config.d/.
stamp="${XDG_CONFIG_HOME:-$HOME/.config}/kkjorsvik/.welcomed"
[ -e "$stamp" ] && exit 0
mkdir -p "$(dirname "$stamp")"
# Give mako a moment to start after the sway session comes up.
sleep 3
notify-send -u normal -t 0 "Welcome to KKjorsvik OS" \
  "Run 'kkjorsvik-setup' in a terminal to install your dev tools, apps, and dotfiles."
: > "$stamp"
```

- [ ] **Step 2: Make it executable and syntax-check it**

Run:
```bash
cd ~/Projects/kkjorsvik-os
chmod +x profile/airootfs/usr/local/bin/kkjorsvik-welcome
sh -n profile/airootfs/usr/local/bin/kkjorsvik-welcome && echo "syntax OK"
shellcheck profile/airootfs/usr/local/bin/kkjorsvik-welcome || true
```
Expected: `syntax OK`; shellcheck reports nothing (or only informational notes).

- [ ] **Step 3: Commit**

```bash
git add profile/airootfs/usr/local/bin/kkjorsvik-welcome
git commit -m "feat: one-time first-login welcome nudge for kkjorsvik-setup"
```

---

## Task 6: Rewrite `kkjorsvik-install` for the new flow

**Files:**
- Modify: `profile/airootfs/usr/local/bin/kkjorsvik-install`

Apply five changes: (a) dotfiles default none, (b) network preflight, (c) pacstrap from `packages.base`, (d) copy desktop configs + wallpaper + welcome script and repoint `$term`, (e) write the target-only welcome drop-in. Replace the whole file with the version below (it preserves the existing partition/chroot/grub logic).

- [ ] **Step 1: Write the new installer**

```bash
#!/usr/bin/env bash
# KKjorsvik OS installer — BIOS/GPT + GRUB, themed sway desktop + a user account.
# Run as root from the live ISO. WARNING: erases the target disk.
set -euo pipefail

DISK="${1:-/dev/sda}"
SHARE=/usr/local/share/kkjorsvik

cleanup() { umount -R /mnt 2>/dev/null || true; }
trap cleanup EXIT

# Strip '#' comments and blank lines from a manifest -> bare package names.
pkglist() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' -e '/^$/d' "$1"; }

echo "=== KKjorsvik OS installer ==="
echo "Target disk: $DISK"
lsblk "$DISK"
read -rp "This will ERASE $DISK. Type YES to continue: " confirm
[[ "$confirm" == "YES" ]] || { echo "Aborted."; exit 1; }
read -rp "Username for your new user account: " NEWUSER
[[ -n "$NEWUSER" ]] || { echo "Username required."; exit 1; }
# Dotfiles are OPT-IN: a fresh box is fully usable bare. Blank answer = none.
read -rp "Dotfiles git repo URL [blank = none; e.g. https://git.kkjorsvik.com/kkjorsvik/dotfiles.git]: " DOTFILES_URL
DOTFILES_URL="${DOTFILES_URL:-}"
[[ "$DOTFILES_URL" == "none" ]] && DOTFILES_URL=""

# Network is required: the base pacstrap (incl. firefox/alacritty) downloads packages.
echo ">> Checking network connectivity..."
if ! ping -c1 -W3 archlinux.org >/dev/null 2>&1; then
  echo "!! No network detected. The installer downloads packages during pacstrap."
  echo "   Connect first (run: nmtui), then re-run kkjorsvik-install."
  exit 1
fi

echo ">> Partitioning $DISK (GPT: 1M BIOS-boot + rest root)..."
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1M  -t1:ef02 -c1:"BIOS boot" "$DISK"
sgdisk -n2:0:0    -t2:8300 -c2:"KKjorsvik root" "$DISK"
partprobe "$DISK"
udevadm settle

# Partition node naming: /dev/sda2, but /dev/nvme0n1p2.
if [[ "$DISK" == *nvme* ]]; then ROOT="${DISK}p2"; else ROOT="${DISK}2"; fi

echo ">> Formatting $ROOT as ext4..."
mkfs.ext4 -F "$ROOT"
mount "$ROOT" /mnt

echo ">> Installing the bootable, themed desktop from packages.base..."
echo "   The curated dev toolchain is installed later by 'kkjorsvik-setup'."
# shellcheck disable=SC2046  # word-splitting the package list is intended
pacstrap -K /mnt $(pkglist "$SHARE/packages.base")

echo ">> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo ">> Applying KKjorsvik branding + desktop configs to the target..."
cp /etc/os-release /mnt/etc/os-release
echo kkjorsvik > /mnt/etc/hostname
install -Dm755 /usr/local/bin/start-sway /mnt/usr/local/bin/start-sway
install -Dm644 /etc/sway/config /mnt/etc/sway/config
# Daily-driver terminal on the installed system is alacritty; the live ISO keeps
# foot (its config.d/90-live-terminal.conf execs foot directly). sway substitutes
# $term at parse time and includes config.d last, so a drop-in can't override it —
# hence a target-side sed.
sed -i 's/^set \$term foot/set $term alacritty/' /mnt/etc/sway/config
# Themed configs for the shell binaries (waybar/mako/fuzzel/foot/alacritty).
for d in waybar mako fuzzel foot alacritty; do
  if [[ -d /etc/xdg/$d ]]; then
    mkdir -p "/mnt/etc/xdg/$d"
    cp -a "/etc/xdg/$d/." "/mnt/etc/xdg/$d/"
  fi
done
# Branded wallpaper (sway's output bg points at this absolute path).
install -Dm644 "$SHARE/wallpaper.png" "/mnt$SHARE/wallpaper.png"
# One-time first-login nudge to run kkjorsvik-setup (installed systems only).
install -Dm755 /usr/local/bin/kkjorsvik-welcome /mnt/usr/local/bin/kkjorsvik-welcome
install -d /mnt/etc/sway/config.d
cat > /mnt/etc/sway/config.d/20-welcome.conf <<'EOF'
# Installed-system only: one-time first-login nudge to run kkjorsvik-setup.
exec /usr/local/bin/kkjorsvik-welcome
EOF

echo ">> Installing curated package manifests + kkjorsvik-setup into the target..."
install -Dm644 "$SHARE/packages.repo" "/mnt$SHARE/packages.repo"
install -Dm644 "$SHARE/packages.aur"  "/mnt$SHARE/packages.aur"
install -Dm755 /usr/local/bin/kkjorsvik-setup "/mnt/usr/local/bin/kkjorsvik-setup"
install -d /mnt/etc/kkjorsvik
printf '%s\n' "$DOTFILES_URL" > /mnt/etc/kkjorsvik/dotfiles-url
# Installed-system login: tuigreet prompt (not autologin) -> sway.
install -d /mnt/etc/greetd
cat > /mnt/etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd /usr/local/bin/start-sway"
user = "greeter"
EOF

echo ">> Configuring the installed system in chroot..."
arch-chroot /mnt /bin/bash -euo pipefail <<CHROOT
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc || true
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="KKjorsvik OS"/' /etc/default/grub
grub-install --target=i386-pc --recheck "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager
systemctl enable greetd
systemctl set-default graphical.target
id "$NEWUSER" &>/dev/null || useradd -m -G wheel "$NEWUSER"
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel
CHROOT

echo ">> Set the password for root:"
arch-chroot /mnt passwd
echo ">> Set the password for $NEWUSER:"
arch-chroot /mnt passwd "$NEWUSER"

echo ">> Unmounting..."
umount -R /mnt
echo "=== Done. Remove the ISO and reboot into KKjorsvik OS. ==="
echo "    You'll boot straight into a themed desktop (bar, wallpaper, launcher)."
echo "    1. Log in at the greeter as '$NEWUSER'."
echo "    2. A welcome note will remind you to run 'kkjorsvik-setup' for your"
echo "       full dev toolchain, apps, and (optional) dotfiles."
```

- [ ] **Step 2: Syntax-check and lint**

Run:
```bash
cd ~/Projects/kkjorsvik-os
bash -n profile/airootfs/usr/local/bin/kkjorsvik-install && echo "syntax OK"
shellcheck profile/airootfs/usr/local/bin/kkjorsvik-install || true
```
Expected: `syntax OK`. shellcheck may warn inside the heredocs/chroot (`$DISK`/`$NEWUSER` expand on the host before chroot — that's intentional and pre-existing); SC2046 on the pacstrap line is silenced by the inline `# shellcheck disable`.

- [ ] **Step 3: Assert the five behavioral changes are present**

Run:
```bash
cd ~/Projects/kkjorsvik-os
f=profile/airootfs/usr/local/bin/kkjorsvik-install
grep -q 'pkglist "\$SHARE/packages.base"' $f && echo "a: pacstrap from base OK"
grep -q 'blank = none' $f && echo "b: dotfiles default none OK"
grep -q 'ping -c1 -W3 archlinux.org' $f && echo "c: network preflight OK"
grep -q 'term alacritty' $f && echo "d: term sed OK"
grep -q '20-welcome.conf' $f && echo "e: welcome drop-in OK"
```
Expected: all five lines print `OK`.

- [ ] **Step 4: Commit**

```bash
git add profile/airootfs/usr/local/bin/kkjorsvik-install
git commit -m "feat: installer ships themed desktop at install time (base pacstrap, wallpaper, welcome, dotfiles none)"
```

---

## Task 7: Reword `kkjorsvik-setup` for its narrower role

**Files:**
- Modify: `profile/airootfs/usr/local/bin/kkjorsvik-setup:2-3`
- Modify: `profile/airootfs/usr/local/bin/kkjorsvik-setup:103`

Setup no longer "sets up the desktop" — the desktop already booted. Only the comments/messages change; the stage logic is unchanged (it still installs from `packages.repo`, bootstraps paru, installs AUR, applies dotfiles).

- [ ] **Step 1: Update the header comment**

Replace lines 2-3:
```
# kkjorsvik-setup — provision a fresh KKjorsvik OS install into the curated dev box.
# Idempotent and safe to re-run. Run as your NORMAL user (not root) after first login.
```
with:
```
# kkjorsvik-setup — add the curated dev toolchain, apps, and optional dotfiles
# on top of the already-running themed desktop. Idempotent and safe to re-run.
# Run as your NORMAL user (not root) after first login.
```

- [ ] **Step 2: Update the success message**

Replace line 103:
```
log "KKjorsvik dev box provisioning complete. A reboot is recommended."
```
with:
```
log "Dev toolchain, apps, and dotfiles installed. A reboot is recommended."
```

- [ ] **Step 3: Syntax-check**

Run:
```bash
cd ~/Projects/kkjorsvik-os
bash -n profile/airootfs/usr/local/bin/kkjorsvik-setup && echo "syntax OK"
```
Expected: `syntax OK`

- [ ] **Step 4: Commit**

```bash
git add profile/airootfs/usr/local/bin/kkjorsvik-setup
git commit -m "docs: reword kkjorsvik-setup for its narrower dev-toolchain role"
```

---

## Task 8: End-to-end build + VM verification (HAND TO USER)

The agent does **not** run this task — building the ISO needs `sudo mkarchiso` and a QEMU/VM session, which the user runs themselves (standing preference). Stop here and hand off the commands below.

- [ ] **Step 1: Build the ISO** (user runs)

```bash
cd ~/Projects/kkjorsvik-os
./build.sh
```
Expected: `out/` gets a new dated ISO; no mkarchiso errors. Watch for "package not found" — a typo in `packages.base` surfaces here.

- [ ] **Step 2: Fresh install in a VM** (user runs)

```bash
cd ~/Projects/kkjorsvik-os
./test-vm-install.sh    # boots ISO with a persistent disk
```
In the VM: run `kkjorsvik-install /dev/vda` (or the shown disk), accept the erase, set a username, leave the dotfiles prompt **blank**, set passwords. Use VirtIO-GPU display (the Proxmox/QEMU GPU note) so sway renders well. `Ctrl+Alt+G` grabs the keyboard.

- [ ] **Step 3: Boot the installed system and verify first-boot UX** (user runs)

```bash
cd ~/Projects/kkjorsvik-os
./test-vm-run.sh        # boots the installed disk, no ISO
```
Verify, **before running kkjorsvik-setup and with no dotfiles**:
- Wallpaper shows (not a black/solid screen).
- Waybar is present (clock, modules, the green focused-workspace pill).
- `Super+d` opens fuzzel; launching firefox works.
- `Super+Return` opens **alacritty** (Gruvbox colors), not foot.
- A one-time "Welcome to KKjorsvik OS" notification appeared; it does **not** reappear after a logout/login.

- [ ] **Step 4: Run setup and confirm it still completes** (user runs)

In the installed VM: `kkjorsvik-setup`. Expected: repo + AUR stages run; with a blank dotfiles URL it prints "No dotfiles URL recorded ... skipping dotfiles"; base packages are `--needed` no-ops. Re-running is safe/idempotent.

- [ ] **Step 5: Report results.** If anything is off (missing package, unthemed terminal, no wallpaper, welcome nagging repeatedly), capture the symptom and we debug before merging.

---

## Self-review notes

- **Spec coverage:** §1 three-tier model → Tasks 1–2; §2 installer changes (pacstrap-from-manifest, config copy, `$term` sed, dotfiles none, network preflight) → Task 6; §3 wallpaper → Task 4; §4 welcome notification → Tasks 5 + 6 (drop-in); §5 setup wording → Task 7. The alacritty config (implied by §2 "copy the alacritty config") is made concrete in Task 3. Verification (§Verification) → Task 8.
- **No placeholders:** every file's full content or exact edit is given; verification commands have expected output.
- **Name consistency:** `pkglist()` (installer) mirrors `manifest()` (setup) — intentionally separate small functions, one per script, no shared dependency. `packages.base` path/name identical across Tasks 1, 2, 6. Wallpaper path `/usr/local/share/kkjorsvik/wallpaper.png` identical in Tasks 4 and 6 and the sway config.
- **Known accepted duplication:** the comment-strip sed appears in both `kkjorsvik-setup` (`manifest()`) and `kkjorsvik-install` (`pkglist()`). Extracting a shared sourced helper for two one-line callers is YAGNI; left as-is.
