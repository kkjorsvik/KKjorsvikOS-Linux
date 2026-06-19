# KKjorsvik OS — sway Desktop Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the KKjorsvik OS live ISO boot straight into a minimal, working sway (Wayland) session — compositor + a terminal (foot) + greetd autologin — with the user's i3 keybinds, verifiable in QEMU.

**Architecture:** Add a small, clearly-labeled desktop package group to the live archiso profile; ship a system-wide `/etc/sway/config` (single canonical config used by every user); auto-start sway via `greetd` through a `start-sway` wrapper that enables software rendering for GPU-less VMs; switch the live ISO's default systemd target to graphical. This is Phase 1 of the M3 desktop spec — deliberately bare (no bar/launcher) to prove the foundation first.

**Tech Stack:** sway, foot, greetd (+ greetd-tuigreet for later phases), polkit; archiso; QEMU with virtio-gpu + llvmpipe software rendering.

**Scope:** Phase 1 only (live ISO). The Phase 2 bundle (waybar/fuzzel/etc.) and Phase 3 installer/disk work are separate future plans.

**Note on verification:** No unit-test framework — each task's "test" is a concrete verification command. The ISO build and QEMU boot require `sudo`/a display and are **run by the user**; agentic workers pause and hand those off.

**Conventions:** Repo root `/home/kkjorsvik/Projects/kkjorsvik-os`. The archiso profile is `profile/`. All commands assume CWD = repo root. Work on a feature branch (see Task 0).

---

### Task 0: Create the feature branch

**Files:** none.

- [ ] **Step 1: Branch from develop**

Run:
```bash
git checkout develop && git checkout -b sway-desktop-phase1 && git branch --show-current
```
Expected: `sway-desktop-phase1`.

---

### Task 1: Add the sway desktop package group to the live ISO

**Files:**
- Modify: `profile/packages.x86_64`

- [ ] **Step 1: Append the desktop package block**

Add these lines to the **end** of `profile/packages.x86_64` (keep the existing list intact; append a labeled block):
```
# --- KKjorsvik desktop (sway, Phase 1) ---
sway
foot
greetd
greetd-tuigreet
polkit
```

- [ ] **Step 2: Verify the packages exist and the file is well-formed**

Run:
```bash
tail -7 profile/packages.x86_64
for p in sway foot greetd greetd-tuigreet polkit; do pacman -Si "$p" >/dev/null 2>&1 && echo "$p OK" || echo "$p MISSING"; done
```
Expected: the appended block is shown, and every package prints `OK`.

- [ ] **Step 3: Commit**

```bash
git add profile/packages.x86_64
git commit -m "Phase 1: add sway desktop package group to live ISO"
```

---

### Task 2: Add the start-sway wrapper and greetd autologin config

**Files:**
- Create: `profile/airootfs/usr/local/bin/start-sway`
- Create: `profile/airootfs/etc/greetd/config.toml`
- Modify: `profile/profiledef.sh` (file permission for the wrapper)

Background: in a VM without a real GPU, wlroots needs `WLR_RENDERER_ALLOW_SOFTWARE=1` to fall back to llvmpipe. The wrapper sets that (harmless on real hardware, where the GPU is still used). greetd runs the wrapper as root on vt1 — the live environment's user — so the ISO boots straight into sway.

- [ ] **Step 1: Create the wrapper**

Create `profile/airootfs/usr/local/bin/start-sway` with exactly:
```bash
#!/bin/sh
# Launch sway. Allow software (llvmpipe) rendering so it also runs in GPU-less VMs.
export WLR_RENDERER_ALLOW_SOFTWARE=1
exec sway
```

- [ ] **Step 2: Create the greetd config (live: autologin into sway)**

Create `profile/airootfs/etc/greetd/config.toml` with exactly:
```toml
[terminal]
vt = 1

[default_session]
command = "/usr/local/bin/start-sway"
user = "root"
```

- [ ] **Step 3: Mark the wrapper executable in the image**

In `profile/profiledef.sh`, add one entry inside the existing `file_permissions=( ... )` array:
```bash
  ["/usr/local/bin/start-sway"]="0:0:755"
```

- [ ] **Step 4: Verify**

Run:
```bash
sh -n profile/airootfs/usr/local/bin/start-sway && echo "wrapper syntax OK"
cat profile/airootfs/etc/greetd/config.toml
grep start-sway profile/profiledef.sh
```
Expected: `wrapper syntax OK`; the TOML contents; and the file_permissions line `["/usr/local/bin/start-sway"]="0:0:755"`.

- [ ] **Step 5: Commit**

```bash
git add profile/airootfs/usr/local/bin/start-sway profile/airootfs/etc/greetd/config.toml profile/profiledef.sh
git commit -m "Phase 1: add start-sway wrapper and greetd autologin config"
```

---

### Task 3: Switch the live ISO to graphical boot and enable greetd

**Files:**
- Create symlink: `profile/airootfs/etc/systemd/system/default.target` → `/usr/lib/systemd/system/graphical.target`
- Create symlink: `profile/airootfs/etc/systemd/system/graphical.target.wants/greetd.service` → `/usr/lib/systemd/system/greetd.service`
- Delete: `profile/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf`

Background: archiso follows the pattern of enabling services via symlinks under `airootfs/etc/systemd/system/*.wants/` (the releng profile already does this). We point the default target at graphical and enable greetd there. The archiso root-on-tty1 autologin is removed so it doesn't contend with greetd for vt1 (Arch's `greetd.service` also declares `Conflicts=getty@tty1.service`).

- [ ] **Step 1: Set the default target to graphical**

Run:
```bash
ln -sf /usr/lib/systemd/system/graphical.target profile/airootfs/etc/systemd/system/default.target
```

- [ ] **Step 2: Enable greetd under graphical.target**

Run:
```bash
mkdir -p profile/airootfs/etc/systemd/system/graphical.target.wants
ln -sf /usr/lib/systemd/system/greetd.service profile/airootfs/etc/systemd/system/graphical.target.wants/greetd.service
```

- [ ] **Step 3: Remove the conflicting TTY autologin override**

Run:
```bash
git rm profile/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf
rmdir profile/airootfs/etc/systemd/system/getty@tty1.service.d 2>/dev/null || true
```

- [ ] **Step 4: Verify the links and removal**

Run:
```bash
readlink profile/airootfs/etc/systemd/system/default.target
readlink profile/airootfs/etc/systemd/system/graphical.target.wants/greetd.service
test ! -e profile/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf && echo "autologin override removed"
```
Expected: `/usr/lib/systemd/system/graphical.target`; `/usr/lib/systemd/system/greetd.service`; `autologin override removed`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Phase 1: boot live ISO to graphical target via greetd (drop tty1 autologin)"
```

---

### Task 4: Ship the canonical sway config with the user's i3 keybinds

**Files:**
- Create: `profile/airootfs/etc/sway/config`

Background: sway reads `/etc/sway/config` for any user without a personal `~/.config/sway/config`, so this one file serves the live root session now and installed users later — the single canonical config. Keybinds mirror the user's i3 config (mod = Super). `$term` is foot (Phase 1's terminal). Phase-2 binds (launcher, browser, files, screenshots, lock, media, notifications) are present but commented so the layout is complete without depending on unshipped packages. `xwayland disable` avoids a startup error since Xwayland isn't installed in Phase 1.

- [ ] **Step 1: Create the sway config**

Create `profile/airootfs/etc/sway/config` with exactly:
```
# KKjorsvik OS — default sway config (Phase 1)
# Clean distro default, mirroring the maintainer's i3 keybinds.

set $mod Mod4
set $term foot

# No Xwayland in Phase 1 (no X apps shipped yet).
xwayland disable

# Title-bar font (a Nerd Font arrives with the Phase 2 bar).
font pango:monospace 10

### Window management (i3-parity) ###
bindsym $mod+Return exec $term
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

### Phase 2 (dormant until those packages ship) ###
# bindsym $mod+d exec fuzzel                 # launcher
# bindsym $mod+b exec chromium               # browser
# bindsym $mod+Shift+f exec thunar           # file manager
# bindsym Print exec grim -g "$(slurp)"      # screenshot
# bindsym $mod+Shift+x exec swaylock         # lock
# bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
# bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
# bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
```

- [ ] **Step 2: Verify**

Run:
```bash
grep -c '^bindsym' profile/airootfs/etc/sway/config
grep -nE 'set \$term|xwayland disable' profile/airootfs/etc/sway/config
```
Expected: a count of roughly 50 active `bindsym` lines; and the `set $term foot` and `xwayland disable` lines shown.

- [ ] **Step 3: Commit**

```bash
git add profile/airootfs/etc/sway/config
git commit -m "Phase 1: ship /etc/sway/config with i3-parity keybinds"
```

---

### Task 5: Make the QEMU test able to run a Wayland compositor

**Files:**
- Modify: `test-qemu.sh`

Background: bare QEMU exposes no DRM device, so sway can't start. A virtio-gpu gives the guest a `/dev/dri` node that llvmpipe can render on, and a compositor wants more RAM than the M1 default.

- [ ] **Step 1: Update the QEMU invocation**

In `test-qemu.sh`, replace this line:
```bash
qemu-system-x86_64 -enable-kvm -m 2G -smp 2 -cdrom "$ISO" -boot d
```
with:
```bash
qemu-system-x86_64 -enable-kvm -m 4G -smp 2 -vga virtio -display gtk -cdrom "$ISO" -boot d
```

- [ ] **Step 2: Verify**

Run:
```bash
bash -n test-qemu.sh && echo "syntax OK"
grep -n 'vga virtio' test-qemu.sh
```
Expected: `syntax OK` and the updated line containing `-vga virtio`.

- [ ] **Step 3: Commit**

```bash
git add test-qemu.sh
git commit -m "Phase 1: give test-qemu.sh a virtio-gpu + more RAM for sway"
```

---

### Task 6: Build and verify in QEMU (USER RUNS THIS)

**Files:** none.

- [ ] **Step 1: Rebuild the ISO**

User runs:
```bash
./build.sh
```
Expected: a fresh `out/kkjorsvik-os-*.iso` (build.sh clears `work/` first). Several minutes.

- [ ] **Step 2: Boot it**

User runs:
```bash
./test-qemu.sh
```
Expected: the VM boots and, instead of a text TTY, comes up into a **sway session** (a mostly-empty gray screen — that's correct for bare sway with no bar/wallpaper).

- [ ] **Step 3: Verify sway works**

In the guest:
- Press **Super+Return** → a **foot** terminal opens.
- In foot run: `echo $WAYLAND_DISPLAY` (expect something like `wayland-1`) and `swaymsg -t get_version` (prints the sway version).
- Test a couple of keybinds: open a second foot (Super+Return), **Super+j/semicolon** to move focus, **Super+Shift+q** to close a window.
- Press **Super+Shift+e** → the exit swaynag prompt appears; choose "Yes, exit" to leave sway.

- [ ] **Step 4: If it lands on a TTY or black screen instead of sway**

Diagnose (don't guess):
- Switch to a VT in the guest if possible, or note the on-screen error.
- The usual culprit is greetd/VT setup. Check: `journalctl -b -u greetd --no-pager | tail -40`.
- If `getty@tty1` grabbed vt1, mask it by adding a symlink in the profile (`ln -sf /dev/null profile/airootfs/etc/systemd/system/getty@tty1.service`), rebuild, retest.
- If sway logs a renderer/DRM error, confirm `-vga virtio` is in the QEMU line and that `WLR_RENDERER_ALLOW_SOFTWARE=1` is exported by `start-sway`.

Report back what you see and we'll fix it together.

**🎉 Phase 1 complete** when the ISO boots into sway and Super+Return gives you a terminal. Next decisions (Phase 2 bundle, Phase 3 installer) are separate plans.

---

## Self-review notes

- Single canonical config realized as `/etc/sway/config` (serves live root now and installed users later) — matches the spec's "one config, no duplication" intent.
- Phase 1 stays minimal: sway + foot + greetd only; bar/launcher/audio binds are written but commented.
- Build and QEMU steps are flagged USER RUNS, consistent with the project's hands-on workflow.
