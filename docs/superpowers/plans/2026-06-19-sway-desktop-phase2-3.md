# KKjorsvik OS — sway Desktop Phase 2 + Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the bare Phase 1 sway session into a themed (Dracula) daily-driver desktop on the live ISO (Milestone A / Phase 2), then make `kkjorsvik-install` put that desktop + a real user account onto disk with a tuigreet login (Milestone B / Phase 3).

**Architecture:** Add the desktop bundle to the archiso package list and ship canonical, system-wide Dracula configs (`/etc/sway/config`, `/etc/xdg/<tool>/`) inherited by the live root session and installed users alike. The installer pacstraps the same bundle and **copies the live env's configs** onto the target (DRY), creates a wheel/sudo user, and sets up greetd+tuigreet → sway.

**Tech Stack:** sway, waybar, fuzzel, mako, swaylock/swayidle/swaybg, grim/slurp, pipewire/wireplumber, chromium, thunar, greetd+tuigreet; archiso; QEMU (virtio-gpu); Proxmox.

**Branch:** `sway-desktop-phase2-3` (already created).

**Note on verification:** No unit-test framework — each task's "test" is a concrete verification command. ISO build, QEMU, and the Proxmox install are **run by the user**; agentic workers pause and hand those off.

**Conventions:** Repo root `/home/kkjorsvik/Projects/kkjorsvik-os`. Profile is `profile/`. Commands assume CWD = repo root.

---

## Milestone A — Phase 2: themed desktop on the live ISO

### Task A1: Add the Phase 2 desktop packages

**Files:** Modify `profile/packages.x86_64`

- [ ] **Step 1: Append the Phase 2 package block**

Append to the END of `profile/packages.x86_64` (keep everything else intact):
```
# --- KKjorsvik desktop bundle (sway, Phase 2) ---
waybar
fuzzel
mako
swaylock
swayidle
swaybg
grim
slurp
wl-clipboard
pipewire
wireplumber
pipewire-pulse
pavucontrol
brightnessctl
xdg-desktop-portal-wlr
xdg-desktop-portal-gtk
ttf-jetbrains-mono-nerd
polkit-gnome
gvfs
chromium
thunar
```

- [ ] **Step 2: Verify all resolve**

Run:
```bash
for p in waybar fuzzel mako swaylock swayidle swaybg grim slurp wl-clipboard pipewire wireplumber pipewire-pulse pavucontrol brightnessctl xdg-desktop-portal-wlr xdg-desktop-portal-gtk ttf-jetbrains-mono-nerd polkit-gnome gvfs chromium thunar; do pacman -Si "$p" >/dev/null 2>&1 && echo "$p OK" || echo "$p MISSING"; done
```
Expected: every line `OK`.

- [ ] **Step 3: Commit**
```bash
git add profile/packages.x86_64
git commit -m "Phase 2: add themed sway desktop bundle (waybar/fuzzel/apps)"
```

---

### Task A2: Replace the sway config with the themed Phase 2 version

**Files:** Modify `profile/airootfs/etc/sway/config` (full replacement)

- [ ] **Step 1: Overwrite `profile/airootfs/etc/sway/config`** with EXACTLY:
```
# KKjorsvik OS — sway config (Phase 2)
# Clean distro default, mirroring the maintainer's i3 keybinds. Dracula theme.

set $mod Mod4
set $term foot
set $menu fuzzel
set $browser chromium
set $files thunar
set $lock swaylock -f -c 282a36

# No Xwayland (chromium runs native Wayland; no X apps shipped).
xwayland disable

font pango:JetBrainsMono Nerd Font 10

### Appearance (Dracula) ###
# class                 border  bg      text    indicator child_border
client.focused          #bd93f9 #bd93f9 #f8f8f2 #ff79c6   #bd93f9
client.focused_inactive #44475a #44475a #f8f8f2 #44475a   #44475a
client.unfocused        #282a36 #282a36 #6272a4 #282a36   #282a36
client.urgent           #ff5555 #ff5555 #f8f8f2 #ff5555   #ff5555

output * bg #282a36 solid_color
default_border pixel 2
gaps inner 6

### Autostart ###
exec waybar
exec mako
exec swayidle -w timeout 600 '$lock' before-sleep '$lock'
exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

### Apps / window management (i3-parity) ###
bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+b exec $browser
bindsym $mod+Shift+f exec $files
bindsym $mod+Shift+q kill
bindsym $mod+f fullscreen toggle
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
bindsym $mod+a focus parent

bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split

bindsym $mod+h split h
bindsym $mod+v split v

# Focus (vim keys + arrows)
bindsym $mod+j focus left
bindsym $mod+k focus down
bindsym $mod+l focus up
bindsym $mod+semicolon focus right
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# Move (vim keys + arrows)
bindsym $mod+Shift+j move left
bindsym $mod+Shift+k move down
bindsym $mod+Shift+l move up
bindsym $mod+Shift+semicolon move right
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

### Workspaces ###
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9
bindsym $mod+0 workspace number 10

bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9
bindsym $mod+Shift+0 move container to workspace number 10

bindsym $mod+Shift+period move workspace to output right
bindsym $mod+Shift+comma move workspace to output left
bindsym $mod+bracketleft workspace prev
bindsym $mod+bracketright workspace next

### Screenshots ###
bindsym Print exec grim -g "$(slurp)" - | wl-copy
bindsym Shift+Print exec grim - | wl-copy

### Lock ###
bindsym $mod+Shift+x exec $lock

### Media / brightness keys ###
bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindsym XF86MonBrightnessUp exec brightnessctl set 5%+
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-

### Session ###
bindsym $mod+Shift+c reload
bindsym $mod+Shift+r reload
bindsym $mod+Shift+e exec swaynag -t warning -m 'Exit sway?' -B 'Yes, exit' 'swaymsg exit'

### Resize mode ###
mode "resize" {
    bindsym j resize shrink width 10 px or 10 ppt
    bindsym k resize grow height 10 px or 10 ppt
    bindsym l resize shrink height 10 px or 10 ppt
    bindsym semicolon resize grow width 10 px or 10 ppt
    bindsym Left resize shrink width 10 px or 10 ppt
    bindsym Down resize grow height 10 px or 10 ppt
    bindsym Up resize shrink height 10 px or 10 ppt
    bindsym Right resize grow width 10 px or 10 ppt
    bindsym Return mode "default"
    bindsym Escape mode "default"
    bindsym $mod+r mode "default"
}
bindsym $mod+r mode "resize"
```

- [ ] **Step 2: Verify**
```bash
grep -nE 'exec waybar|exec \$menu|JetBrainsMono|solid_color' profile/airootfs/etc/sway/config
grep -c '^bindsym' profile/airootfs/etc/sway/config
```
Expected: the autostart/font/bg lines shown; bindsym count around 60.

- [ ] **Step 3: Commit**
```bash
git add profile/airootfs/etc/sway/config
git commit -m "Phase 2: themed (Dracula) sway config with bundle binds + autostart"
```

---

### Task A3: Add the waybar config and stylesheet

**Files:**
- Create `profile/airootfs/etc/xdg/waybar/config`
- Create `profile/airootfs/etc/xdg/waybar/style.css`

waybar reads `/etc/xdg/waybar/` as the system-wide default (after a user's own).

- [ ] **Step 1: Create `profile/airootfs/etc/xdg/waybar/config`** with EXACTLY:
```json
{
  "layer": "top",
  "position": "top",
  "height": 28,
  "modules-left": ["sway/workspaces", "sway/mode"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio", "network", "cpu", "memory", "tray"],
  "sway/workspaces": { "disable-scroll": true, "all-outputs": true },
  "sway/mode": { "format": "<span style=\"italic\">{}</span>" },
  "clock": { "format": "{:%a %d %b  %H:%M}" },
  "cpu": { "format": " {usage}%" },
  "memory": { "format": " {percentage}%" },
  "network": {
    "format-wifi": " {essid}",
    "format-ethernet": " {ifname}",
    "format-disconnected": "⚠ offline"
  },
  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": " muted",
    "format-icons": { "default": ["", "", ""] },
    "on-click": "pavucontrol"
  },
  "tray": { "spacing": 8 }
}
```

- [ ] **Step 2: Create `profile/airootfs/etc/xdg/waybar/style.css`** with EXACTLY:
```css
* {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 13px;
  min-height: 0;
}
window#waybar {
  background-color: #282a36;
  color: #f8f8f2;
}
#workspaces button {
  padding: 0 8px;
  background-color: transparent;
  color: #6272a4;
}
#workspaces button.focused {
  color: #f8f8f2;
  background-color: #44475a;
  border-bottom: 2px solid #bd93f9;
}
#mode, #clock, #cpu, #memory, #network, #pulseaudio, #tray {
  padding: 0 10px;
}
#clock { color: #8be9fd; }
#cpu { color: #50fa7b; }
#memory { color: #ffb86c; }
#network { color: #bd93f9; }
#pulseaudio { color: #ff79c6; }
#pulseaudio.muted { color: #6272a4; }
```

- [ ] **Step 3: Verify**
```bash
python3 -c "import json,sys; json.load(open('profile/airootfs/etc/xdg/waybar/config')); print('waybar config JSON OK')"
test -s profile/airootfs/etc/xdg/waybar/style.css && echo "style.css present"
```
Expected: `waybar config JSON OK` and `style.css present`.

- [ ] **Step 4: Commit**
```bash
git add profile/airootfs/etc/xdg/waybar/config profile/airootfs/etc/xdg/waybar/style.css
git commit -m "Phase 2: add Dracula-themed waybar config + stylesheet"
```

---

### Task A4: Add foot, fuzzel, and mako configs (Dracula)

**Files:**
- Create `profile/airootfs/etc/xdg/foot/foot.ini`
- Create `profile/airootfs/etc/xdg/fuzzel/fuzzel.ini`
- Create `profile/airootfs/etc/xdg/mako/config`

- [ ] **Step 1: Create `profile/airootfs/etc/xdg/foot/foot.ini`** with EXACTLY:
```ini
font=JetBrainsMono Nerd Font:size=11

[colors]
background=282a36
foreground=f8f8f2
regular0=21222c
regular1=ff5555
regular2=50fa7b
regular3=f1fa8c
regular4=bd93f9
regular5=ff79c6
regular6=8be9fd
regular7=f8f8f2
bright0=6272a4
bright1=ff6e6e
bright2=69ff94
bright3=ffffa5
bright4=d6acff
bright5=ff92df
bright6=a4ffff
bright7=ffffff
```

- [ ] **Step 2: Create `profile/airootfs/etc/xdg/fuzzel/fuzzel.ini`** with EXACTLY:
```ini
[main]
font=JetBrainsMono Nerd Font:size=12

[colors]
background=282a36ff
text=f8f8f2ff
match=ff79c6ff
selection=44475aff
selection-text=f8f8f2ff
selection-match=ff79c6ff
border=bd93f9ff
```

- [ ] **Step 3: Create `profile/airootfs/etc/xdg/mako/config`** with EXACTLY:
```ini
font=JetBrainsMono Nerd Font 11
background-color=#282a36
text-color=#f8f8f2
border-color=#bd93f9
border-size=2
border-radius=6
default-timeout=5000
```

- [ ] **Step 4: Verify**
```bash
for f in foot/foot.ini fuzzel/fuzzel.ini mako/config; do test -s "profile/airootfs/etc/xdg/$f" && echo "$f OK"; done
grep -l JetBrainsMono profile/airootfs/etc/xdg/foot/foot.ini profile/airootfs/etc/xdg/fuzzel/fuzzel.ini profile/airootfs/etc/xdg/mako/config
```
Expected: all three `OK` and listed.

- [ ] **Step 5: Commit**
```bash
git add profile/airootfs/etc/xdg/foot profile/airootfs/etc/xdg/fuzzel profile/airootfs/etc/xdg/mako
git commit -m "Phase 2: add Dracula foot/fuzzel/mako configs"
```

---

### Task A5: Build and verify Phase 2 in QEMU (USER RUNS THIS)

**Files:** none.

- [ ] **Step 1: Rebuild** — user runs `./build.sh` (clears `work/`, several minutes).
- [ ] **Step 2: Boot** — user runs `./test-qemu.sh`; **click the window + Ctrl+Alt+G** to grab the keyboard.
- [ ] **Step 3: Verify the themed desktop**
  - A **waybar** bar is visible across the top; the background is **Dracula purple** (`#282a36`), not gray.
  - **Super+Return** → a Dracula-themed **foot** terminal.
  - **Super+d** → **fuzzel** launcher appears; type `foot` + Enter launches one.
  - **Super+Shift+x** → screen locks (swaylock); unlock with your... it's the live ISO root (no password) — press Enter/Escape to dismiss, or skip this check.
  - **Super+b** → chromium starts (may be slow in the VM); **Super+Shift+f** → thunar.
- [ ] **Step 4: If something's off** (blank bar, wrong font glyphs, an autostart missing): from a foot terminal run `journalctl --user -b --no-pager | tail -40` and `swaymsg -t get_outputs`, and report. Don't guess.

**🎉 Milestone A complete** when waybar + Dracula theme are visible and `Super+d` launches apps.

---

## Milestone B — Phase 3: installer puts the desktop + a user on disk

### Task B1: Rewrite kkjorsvik-install to install the desktop and a user

**Files:** Modify `profile/airootfs/usr/local/bin/kkjorsvik-install` (full replacement)

- [ ] **Step 1: Overwrite `profile/airootfs/usr/local/bin/kkjorsvik-install`** with EXACTLY:
```bash
#!/usr/bin/env bash
# KKjorsvik OS installer — BIOS/GPT + GRUB, sway desktop + a user account.
# Run as root from the live ISO. WARNING: erases the target disk.
set -euo pipefail

DISK="${1:-/dev/sda}"

cleanup() { umount -R /mnt 2>/dev/null || true; }
trap cleanup EXIT

echo "=== KKjorsvik OS installer ==="
echo "Target disk: $DISK"
lsblk "$DISK"
read -rp "This will ERASE $DISK. Type YES to continue: " confirm
[[ "$confirm" == "YES" ]] || { echo "Aborted."; exit 1; }
read -rp "Username for your new user account: " NEWUSER
[[ -n "$NEWUSER" ]] || { echo "Username required."; exit 1; }

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

echo ">> Installing base system + sway desktop with pacstrap (this takes a while)..."
pacstrap -K /mnt \
  base linux linux-firmware grub vim sudo networkmanager \
  sway foot greetd greetd-tuigreet polkit \
  waybar fuzzel mako swaylock swayidle swaybg grim slurp wl-clipboard \
  pipewire wireplumber pipewire-pulse pavucontrol brightnessctl \
  xdg-desktop-portal-wlr xdg-desktop-portal-gtk ttf-jetbrains-mono-nerd \
  polkit-gnome gvfs chromium thunar

echo ">> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo ">> Applying KKjorsvik branding + desktop configs to the target..."
cp /etc/os-release /mnt/etc/os-release
echo kkjorsvik > /mnt/etc/hostname
# Canonical configs already live in this ISO — copy them onto the target (DRY).
install -Dm755 /usr/local/bin/start-sway /mnt/usr/local/bin/start-sway
install -Dm644 /etc/sway/config /mnt/etc/sway/config
for d in waybar foot fuzzel mako; do
  [ -e "/etc/xdg/$d" ] && cp -rT "/etc/xdg/$d" "/mnt/etc/xdg/$d"
done
# Installed-system login: tuigreet prompt (not autologin) -> sway.
install -d /mnt/etc/greetd
cat > /mnt/etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd /usr/local/bin/start-sway"
user = "greetd"
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
useradd -m -G wheel "$NEWUSER"
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
echo "    Log in at the greeter as '$NEWUSER'."
```

- [ ] **Step 2: Verify the script**
```bash
bash -n profile/airootfs/usr/local/bin/kkjorsvik-install && echo "syntax OK"
grep -nE 'useradd|tuigreet|pacstrap|10-wheel' profile/airootfs/usr/local/bin/kkjorsvik-install
grep -n 'arch-chroot /mnt /bin/bash' profile/airootfs/usr/local/bin/kkjorsvik-install
```
Expected: `syntax OK`; the useradd/tuigreet/pacstrap/sudoers lines; and the chroot heredoc line reading `arch-chroot /mnt /bin/bash -euo pipefail <<CHROOT` (UNQUOTED, so `$DISK`/`$NEWUSER` expand).

- [ ] **Step 3: Commit**
```bash
git add profile/airootfs/usr/local/bin/kkjorsvik-install
git commit -m "Phase 3: installer lays down sway desktop + a wheel user, tuigreet login"
```

---

### Task B2: Build and verify Phase 3 install in Proxmox (USER RUNS THIS)

**Files:** none.

- [ ] **Step 1: Rebuild** — user runs `./build.sh`, then uploads the new ISO to Proxmox.
- [ ] **Step 2: VM** — create/boot a Proxmox VM with **BIOS = SeaBIOS**, **Display = VirtIO-GPU**, a ~20 GB disk (`/dev/sda`), network attached, ISO as CD-ROM (boot CD first).
- [ ] **Step 3: Install** — in the live session open a terminal (Super+Return) and run:
  ```bash
  kkjorsvik-install /dev/sda
  ```
  Type `YES`, enter a username, and set both the root and user passwords when prompted. Expect: `=== Done ... ===` and `Log in at the greeter as '<user>'.`
- [ ] **Step 4: Reboot** — set the VM to boot from disk (detach the ISO), reboot. Expect GRUB → a **tuigreet** login prompt.
- [ ] **Step 5: Verify** — log in as your new user; you should land in the themed sway desktop (waybar + Dracula). In a terminal:
  ```bash
  whoami                       # your username
  groups                       # includes wheel
  sudo -v && echo sudo-ok      # sudo works after password
  systemctl is-enabled greetd  # enabled
  ```
- [ ] **Step 6: If the greeter doesn't appear or login fails to start sway**: switch to a VT or check `journalctl -b -u greetd --no-pager | tail -40` and report. Don't guess.

**🎉 Milestone B complete** when you log in through tuigreet as your user into the themed sway desktop.

---

## Self-review notes
- Spec coverage: packages (A1), themed sway config + binds/autostart/bg (A2), waybar (A3), foot/fuzzel/mako (A4), installer user-account + desktop + config-copy + tuigreet (B1). Verifications A5/B2 cover both test plans.
- DRY: installer copies the live env's canonical configs rather than re-listing them.
- The live greetd (autologin root, Phase 1) and installed greetd (tuigreet, Phase 3) intentionally differ.
