# Curated Dev Box Provisioning — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a fresh KKjorsvik OS install provision itself into a curated "ideal dev box" — a deliberate set of official + AUR software plus chezmoi-managed dotfiles — via a re-runnable first-boot script.

**Architecture:** Hybrid. The disk installer (`kkjorsvik-install`) lays only the bootable-sway floor and records the dotfiles URL. A separate, idempotent `kkjorsvik-setup` script run on first boot (as the normal user) installs the curated official packages, bootstraps `paru` + installs AUR packages, and applies dotfiles with `chezmoi`. Two plain-text manifests (`packages.repo`, `packages.aur`) are the single source of truth for software.

**Tech Stack:** Bash, archiso, pacman, paru (AUR), chezmoi, sway/Wayland.

**Spec:** `docs/superpowers/specs/2026-06-19-curated-dev-box-provisioning-design.md`

---

## File Structure

| File | Responsibility |
|------|----------------|
| `profile/airootfs/usr/local/share/kkjorsvik/packages.repo` | **New.** Curated official-repo package list. |
| `profile/airootfs/usr/local/share/kkjorsvik/packages.aur` | **New.** Curated AUR package list. |
| `profile/airootfs/usr/local/bin/kkjorsvik-setup` | **New.** Idempotent first-boot provisioner. |
| `profile/airootfs/usr/local/bin/kkjorsvik-install` | **Modify.** Trim pacstrap to the bootable floor; prompt for dotfiles URL; copy manifests + setup script into target; write `/etc/kkjorsvik/dotfiles-url`; drop the rich desktop-config hand-copy. |
| `README.md` | **Modify.** Document the install → `kkjorsvik-setup` flow. |

Everything under `profile/airootfs/` is baked into the ISO by `mkarchiso`, so it lands on the live system at the same path (e.g. `/usr/local/bin/kkjorsvik-setup`). The installer then copies the relevant pieces onto the installed target.

**Note on TDD for shell:** There is no unit-test harness in this repo; the "tests" are `bash -n` syntax checks, `shellcheck` (when available), and QEMU smoke runs. Build/QEMU/install steps are **run by you** (the human), since they need `sudo`, KVM, and a throwaway disk — they are marked **[run yourself]**.

---

## Task 1: Curated package manifests

**Files:**
- Create: `profile/airootfs/usr/local/share/kkjorsvik/packages.repo`
- Create: `profile/airootfs/usr/local/share/kkjorsvik/packages.aur`

- [ ] **Step 1: Write `packages.repo`**

Create `profile/airootfs/usr/local/share/kkjorsvik/packages.repo` with exactly:

```
# KKjorsvik OS — official-repo package manifest.
# Installed by kkjorsvik-setup via: pacman -S --needed -
# One package per line. '#' comments and blank lines are ignored.
# This is the curated "ideal dev box", not a clone — edit deliberately.

# === Core CLI & system ===
base-devel
git
fish
neovim
vim
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

# === Sway desktop (Wayland) ===
sway
swaybg
swaylock
swayidle
waybar
foot
fuzzel
mako
grim
slurp
wl-clipboard
brightnessctl
playerctl
polkit
polkit-gnome
nwg-look
xdg-desktop-portal-wlr
xdg-desktop-portal-gtk
xdg-utils
gvfs

# === Audio (PipeWire) ===
pipewire
pipewire-alsa
pipewire-jack
pipewire-pulse
wireplumber
gst-plugin-pipewire
pavucontrol

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

# === GUI apps ===
ghostty
zed
code
firefox
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

# === Fonts ===
ttf-jetbrains-mono-nerd
ttf-firacode-nerd
ttf-nerd-fonts-symbols
ttf-nerd-fonts-symbols-mono
noto-fonts
noto-fonts-emoji
woff2-font-awesome

# === Distro-building (optional — keep if you build kkjorsvik-os on this box) ===
archiso
qemu-full
```

- [ ] **Step 2: Write `packages.aur`**

Create `profile/airootfs/usr/local/share/kkjorsvik/packages.aur` with exactly:

```
# KKjorsvik OS — AUR package manifest.
# Installed by kkjorsvik-setup via paru (bootstrapped automatically): paru -S --needed -
# One package per line. '#' comments and blank lines are ignored.

# === AI / dev CLIs ===
claude-code
openai-codex-bin
qwen-code-bin

# === Editors / IDEs ===
cursor-bin
sublime-text-4
jetbrains-toolbox

# === Runtimes ===
bun-bin

# === Cloud / DevOps ===
flyctl
rancher-k3d-bin
aws-cdk

# === Apps ===
slack-desktop
proton-mail-bin
anytype-bin
hoppscotch-bin
```

- [ ] **Step 3: Verify the manifests parse cleanly**

Run:
```bash
for f in profile/airootfs/usr/local/share/kkjorsvik/packages.repo \
         profile/airootfs/usr/local/share/kkjorsvik/packages.aur; do
  echo "== $f =="
  sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$f" | sort | uniq -d   # prints nothing if no dupes
  echo "count: $(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$f" | grep -c .)"
done
```
Expected: no duplicate lines printed; a sensible count (repo ≈ 110, aur ≈ 14).

- [ ] **Step 4: Curation review [run yourself]**

This is the human curation gate. Read both files and adjust to taste. Known deliberate cuts from the current machine, listed so you can re-add any you miss:
- **Terminals:** kept `ghostty` (+ `foot` for sway). Dropped `alacritty`, `kitty`, `wezterm`, `xterm`, `warp`.
- **Editors:** kept `neovim`, `zed`, `code`, plus AUR `cursor-bin`, `sublime-text-4`. Dropped `micro`, `nano`.
- **i3/X11 stack dropped entirely** (sway is canonical): `i3-wm`, `i3blocks`, `i3lock`, `i3status`, `i3status-rust`, `polybar`, `dmenu`, `rofi`, `dunst`, `picom`, `feh`, `nitrogen`, plus the `xorg-*` and X-only video drivers. Sway equivalents: `mako` (dunst), `fuzzel` (rofi/dmenu), `waybar` (polybar/i3status).
- **Fonts:** trimmed ~80 nerd-font packages to 4 + Noto. Re-add any specific family you rely on.
- **`ollama`:** plain CPU/auto build. Swap for `ollama-cuda` or `ollama-vulkan` to match your GPU.
- **`opentofu`** kept over `terraform` (you had both). Re-add `terraform` if you need it.
- **Dropped AUR:** `warp`, `antigravity-bin`, `t3code-bin`, `opencode-desktop-bin`, `discordo-git`, `mirage`, `pencil`, `thonny`, `steampipe-bin`, `grype-bin`, `tfsec-bin`, `cursor-cli`, `nodejs-nestjs-cli`, `elixir-ls`, `canon-pixma-ts5055-complete` (printer-specific), `apache-tools`. Re-add as needed.

- [ ] **Step 5: Commit**

```bash
git add profile/airootfs/usr/local/share/kkjorsvik/packages.repo \
        profile/airootfs/usr/local/share/kkjorsvik/packages.aur
git commit -m "feat: curated official + AUR package manifests for dev box"
```

---

## Task 2: `kkjorsvik-setup` first-boot provisioner

**Files:**
- Create: `profile/airootfs/usr/local/bin/kkjorsvik-setup`

- [ ] **Step 1: Write the script**

Create `profile/airootfs/usr/local/bin/kkjorsvik-setup` with exactly:

```bash
#!/usr/bin/env bash
# kkjorsvik-setup — provision a fresh KKjorsvik OS install into the curated dev box.
# Idempotent and safe to re-run. Run as your NORMAL user (not root) after first login.
set -uo pipefail

SHARE=/usr/local/share/kkjorsvik
REPO_LIST="$SHARE/packages.repo"
AUR_LIST="$SHARE/packages.aur"
URL_FILE=/etc/kkjorsvik/dotfiles-url

failed=()

log()  { printf '\033[1;34m>>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# Strip '#' comments and blank lines from a manifest, emit one package per line.
manifest() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1"; }

# --- Stage 0: preflight ---
[[ $EUID -ne 0 ]] || die "Run as your normal user, not root — the script uses sudo itself."
command -v sudo >/dev/null || die "sudo not found."
sudo -v || die "sudo authentication failed."
if ! ping -c1 -W3 archlinux.org >/dev/null 2>&1; then
  warn "Network check failed (couldn't reach archlinux.org). Continuing, but installs may fail."
fi

# --- Stage 1: official-repo packages ---
if [[ -f "$REPO_LIST" ]]; then
  log "Installing official-repo packages from $REPO_LIST ..."
  if ! manifest "$REPO_LIST" | sudo pacman -S --needed --noconfirm -; then
    warn "Some official-repo packages failed to install."
    failed+=("repo packages")
  fi
else
  warn "$REPO_LIST not found; skipping repo packages."
fi

# --- Stage 2: paru bootstrap (AUR helper) ---
if ! command -v paru >/dev/null; then
  log "Bootstrapping paru from the AUR ..."
  if ! command -v git >/dev/null || ! command -v makepkg >/dev/null; then
    warn "git or base-devel missing; cannot bootstrap paru. Skipping AUR."
    failed+=("paru bootstrap")
  else
    tmp="$(mktemp -d)"
    if git clone --depth=1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin" \
       && ( cd "$tmp/paru-bin" && makepkg -si --noconfirm ); then
      log "paru installed."
    else
      warn "paru bootstrap failed; skipping AUR stage."
      failed+=("paru bootstrap")
    fi
    rm -rf "$tmp"
  fi
fi

# --- Stage 3: AUR packages ---
if command -v paru >/dev/null && [[ -f "$AUR_LIST" ]]; then
  log "Installing AUR packages from $AUR_LIST ..."
  if ! manifest "$AUR_LIST" | paru -S --needed --noconfirm -; then
    warn "Some AUR packages failed to install."
    failed+=("AUR packages")
  fi
fi

# --- Stage 4: dotfiles via chezmoi ---
if [[ -s "$URL_FILE" ]]; then
  url="$(tr -d '[:space:]' < "$URL_FILE")"
  if [[ -z "$url" ]]; then
    log "Dotfiles URL file is empty; skipping dotfiles."
  elif command -v chezmoi >/dev/null; then
    log "Applying dotfiles from $url via chezmoi ..."
    if ! chezmoi init --apply "$url"; then
      warn "chezmoi failed to apply dotfiles."
      failed+=("dotfiles")
    fi
  else
    warn "chezmoi not installed (add it to packages.repo); skipping dotfiles."
  fi
else
  log "No dotfiles URL recorded at $URL_FILE; skipping dotfiles."
fi

# --- Summary ---
if ((${#failed[@]})); then
  warn "Finished with issues in: ${failed[*]}"
  warn "Fix the cause, then re-run 'kkjorsvik-setup' — it is safe to run again."
  exit 1
fi
log "KKjorsvik dev box provisioning complete. A reboot is recommended."
```

- [ ] **Step 2: Make it executable**

Run:
```bash
chmod +x profile/airootfs/usr/local/bin/kkjorsvik-setup
```

- [ ] **Step 3: Syntax + lint check**

Run:
```bash
bash -n profile/airootfs/usr/local/bin/kkjorsvik-setup && echo "syntax OK"
command -v shellcheck >/dev/null && shellcheck profile/airootfs/usr/local/bin/kkjorsvik-setup || echo "(shellcheck not installed — skipped)"
```
Expected: `syntax OK`; shellcheck reports no errors (warnings about `SC2155`/style are acceptable).

- [ ] **Step 4: Dry-run the manifest parser locally [run yourself]**

Confirm the comment-stripping matches what the installer/setup expect:
```bash
sed -e 's/#.*//' -e '/^[[:space:]]*$/d' \
  profile/airootfs/usr/local/share/kkjorsvik/packages.repo | head
```
Expected: clean package names, no `#` lines, no blanks.

- [ ] **Step 5: Commit**

```bash
git add profile/airootfs/usr/local/bin/kkjorsvik-setup
git commit -m "feat: kkjorsvik-setup first-boot provisioner (repo+AUR+chezmoi)"
```

---

## Task 3: Installer integration

**Files:**
- Modify: `profile/airootfs/usr/local/bin/kkjorsvik-install`

- [ ] **Step 1: Add the dotfiles-URL prompt**

In `kkjorsvik-install`, find the username block (around line 16-17):
```bash
read -rp "Username for your new user account: " NEWUSER
[[ -n "$NEWUSER" ]] || { echo "Username required."; exit 1; }
```
Add immediately after it:
```bash
DEFAULT_DOTFILES_URL="https://git.kkjorsvik.com/kkjorsvik/dotfiles.git"
read -rp "Dotfiles git repo URL [${DEFAULT_DOTFILES_URL}] (type 'none' to skip): " DOTFILES_URL
DOTFILES_URL="${DOTFILES_URL:-$DEFAULT_DOTFILES_URL}"
[[ "$DOTFILES_URL" == "none" ]] && DOTFILES_URL=""
```

- [ ] **Step 2: Trim pacstrap to the bootable floor**

Replace the whole pacstrap block (currently lines ~33-40, the `echo ">> Installing base system + sway desktop..."` line through the `polkit-gnome gvfs chromium thunar` line) with:
```bash
echo ">> Installing the minimal bootable system (base + sway login)..."
echo "   The full curated software set is installed later by 'kkjorsvik-setup'."
pacstrap -K /mnt \
  base linux linux-firmware grub sudo vim networkmanager \
  sway foot greetd greetd-tuigreet polkit \
  pipewire wireplumber pipewire-pulse
```

- [ ] **Step 3: Replace the desktop-config hand-copy with a minimal fallback**

Find this block (currently lines ~48-53):
```bash
# Canonical configs already live in this ISO — copy them onto the target (DRY).
install -Dm755 /usr/local/bin/start-sway /mnt/usr/local/bin/start-sway
install -Dm644 /etc/sway/config /mnt/etc/sway/config
for d in waybar foot fuzzel mako; do
  [ -e "/etc/xdg/$d" ] && cp -rT "/etc/xdg/$d" "/mnt/etc/xdg/$d"
done
```
Replace it with (keep `start-sway` + a minimal `/etc/sway` fallback; the rich user config comes from chezmoi):
```bash
# Minimal sway fallback so the box boots to a usable session before
# kkjorsvik-setup runs. The rich desktop config is owned by chezmoi (~/.config).
install -Dm755 /usr/local/bin/start-sway /mnt/usr/local/bin/start-sway
install -Dm644 /etc/sway/config /mnt/etc/sway/config
```

- [ ] **Step 4: Copy manifests + setup script + record the dotfiles URL**

Immediately after the block from Step 3, add:
```bash
echo ">> Installing curated package manifests + kkjorsvik-setup into the target..."
install -Dm644 /usr/local/share/kkjorsvik/packages.repo /mnt/usr/local/share/kkjorsvik/packages.repo
install -Dm644 /usr/local/share/kkjorsvik/packages.aur  /mnt/usr/local/share/kkjorsvik/packages.aur
install -Dm755 /usr/local/bin/kkjorsvik-setup           /mnt/usr/local/bin/kkjorsvik-setup
install -d /mnt/etc/kkjorsvik
printf '%s\n' "$DOTFILES_URL" > /mnt/etc/kkjorsvik/dotfiles-url
```

- [ ] **Step 5: Update the closing instructions**

Find the final messages (currently lines ~90-91):
```bash
echo "=== Done. Remove the ISO and reboot into KKjorsvik OS. ==="
echo "    Log in at the greeter as '$NEWUSER'."
```
Replace with:
```bash
echo "=== Done. Remove the ISO and reboot into KKjorsvik OS. ==="
echo "    1. Log in at the greeter as '$NEWUSER'."
echo "    2. Connect to the network if needed (nmtui)."
echo "    3. Run 'kkjorsvik-setup' to install your curated software + dotfiles."
```

- [ ] **Step 6: Syntax + lint check**

Run:
```bash
bash -n profile/airootfs/usr/local/bin/kkjorsvik-install && echo "syntax OK"
command -v shellcheck >/dev/null && shellcheck profile/airootfs/usr/local/bin/kkjorsvik-install || echo "(shellcheck skipped)"
```
Expected: `syntax OK`; no shellcheck errors.

- [ ] **Step 7: Commit**

```bash
git add profile/airootfs/usr/local/bin/kkjorsvik-install
git commit -m "feat: installer records dotfiles URL, ships manifests + setup, trims pacstrap to bootable floor"
```

---

## Task 4: Documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a "Make it your dev box" section**

In `README.md`, after the existing "Install to a disk" section, add:
```markdown
## Make it your dev box

The installer lays down a minimal bootable sway system and records your
dotfiles repo URL. The curated software and your configs are applied on first
boot by `kkjorsvik-setup`:

1. Boot the installed system and log in as your user.
2. Bring up networking if needed: `nmtui`.
3. Run the provisioner:

   ```sh
   kkjorsvik-setup
   ```

It installs the official-repo packages (`/usr/local/share/kkjorsvik/packages.repo`),
bootstraps `paru` and installs the AUR packages (`packages.aur`), then applies
your dotfiles with `chezmoi init --apply <your-repo>`. It is **idempotent** —
re-run it any time after editing a manifest; already-installed packages are
skipped.

Curate your software by editing the two manifest files in
`profile/airootfs/usr/local/share/kkjorsvik/` and rebuilding the ISO.
```

- [ ] **Step 2: Verify the README renders sensibly [run yourself]**

Run:
```bash
glow README.md | head -80   # or just open it
```
Expected: the new section appears, code fences intact.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document the kkjorsvik-setup dev-box provisioning flow"
```

---

## Task 5: End-to-end verification [run yourself]

This task has no code; it proves the whole pipeline. All steps need `sudo`/KVM and are run by you.

- [ ] **Step 1: Build the ISO**

Run:
```bash
./build.sh
```
Expected: completes, producing `out/kkjorsvik-os-<date>-x86_64.iso`.

- [ ] **Step 2: Confirm the new files are inside the ISO airootfs**

The build prints the work dir; the squashfs contents come from `profile/airootfs`. Quick sanity check that they are staged:
```bash
ls -l profile/airootfs/usr/local/bin/kkjorsvik-setup \
      profile/airootfs/usr/local/share/kkjorsvik/packages.repo \
      profile/airootfs/usr/local/share/kkjorsvik/packages.aur
```
Expected: all three exist; `kkjorsvik-setup` is executable.

- [ ] **Step 3: Boot the ISO and install into a throwaway VM**

Run `./test-qemu.sh`, then inside the live system:
```sh
lsblk
kkjorsvik-install /dev/sda     # type YES, set a username, accept the default dotfiles URL
```
Expected: installer trims to the minimal pacstrap, copies manifests + `kkjorsvik-setup`, writes `/etc/kkjorsvik/dotfiles-url`, and prints the 3-step "run kkjorsvik-setup" closing message.

- [ ] **Step 4: Boot the installed disk and verify the handoff artifacts**

Reboot into the installed system, log in as your user, then:
```sh
cat /etc/kkjorsvik/dotfiles-url            # your chosen URL
ls /usr/local/share/kkjorsvik/             # packages.repo packages.aur
command -v kkjorsvik-setup                 # /usr/local/bin/kkjorsvik-setup
```
Expected: all present and correct.

- [ ] **Step 5: Run the provisioner**

```sh
nmtui            # ensure networking
kkjorsvik-setup
```
Expected: official packages install, `paru` bootstraps, AUR packages install, `chezmoi init --apply` runs against the (currently near-empty) dotfiles repo, ends with the completion message. Note any package that fails for the curation follow-up.

- [ ] **Step 6: Re-run to prove idempotency**

```sh
kkjorsvik-setup
```
Expected: second run is fast, installs nothing new (`--needed` skips everything), `chezmoi` reports no changes, exits 0.

- [ ] **Step 7: Record results [run yourself]**

Note in the PR/commit any packages that failed or needed curation. These feed back into the manifests (Task 1) and into sub-project 2 (the dotfiles repo).

---

## Self-Review Notes

**Spec coverage:**
- Package manifests (`packages.repo`/`packages.aur`, categorized, `/usr/local/share/kkjorsvik/`) → Task 1. ✅
- `kkjorsvik-setup` 6 stages (preflight, repo, paru, AUR, chezmoi, summary), idempotent → Task 2. ✅
- Installer: URL prompt + default, copy manifests + setup, write `/etc/kkjorsvik/dotfiles-url`, minimal sway fallback, trimmed pacstrap floor, updated closing message → Task 3. ✅
- Curation as a human review gate → Task 1 Step 4. ✅
- chezmoi accepts any git URL (Forgejo) → uses `chezmoi init --apply "$url"` verbatim, no host special-casing. ✅
- Testing (build, install, setup, idempotency, blank-URL skip) → Task 5 + Task 2 logic. ✅

**Deviation from spec (intentional):** spec said "blank to skip" the dotfiles URL, but blank is needed to accept the default. Resolved by: empty input → default URL; literal `none` → skip. Documented in the prompt text and README.

**Deferred (out of scope, per spec):** auto-run of `kkjorsvik-setup` on first boot; enabling system services (docker/bluetooth/cups) and adding the user to the `docker` group — note this so a follow-up milestone or the dotfiles repo handles it; UEFI install path; chezmoi templating/secrets.

**Placeholder scan:** no TBD/TODO; every script and config step contains complete content. ✅

**Consistency:** `manifest()` parser identical in setup and in verification steps; `/etc/kkjorsvik/dotfiles-url` written by installer (Task 3 Step 4) and read by setup (Task 2 Stage 4); `chezmoi` present via `packages.repo` before Stage 4 uses it. ✅
