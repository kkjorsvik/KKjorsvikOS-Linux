# Curated Dev Box Provisioning — Design

**Date:** 2026-06-19
**Status:** Approved (design); implementation pending
**Scope:** Sub-project 1 of 2 — the provisioning *engine* in `kkjorsvik-os`.
Sub-project 2 (the chezmoi dotfiles repo) gets its own spec.

## Goal

Turn a fresh KKjorsvik OS install into a deliberate, reproducible "perfect dev
box" — the curated set of go-to software plus personal configs — without
carrying forward the accumulated cruft of the current machine. The repo becomes
the source of truth; the current machine is only where the initial list is
harvested from.

## Decisions (locked during brainstorming)

- **Model:** curated *ideal* dev box, not a faithful clone. Improving on the
  current system is an explicit goal (collapse redundant terminals/editors,
  trim fonts, drop build-only tooling).
- **Dotfiles:** live in a **separate git repo**, applied with **chezmoi**.
  Repo: `https://git.kkjorsvik.com/kkjorsvik/dotfiles.git` (self-hosted
  Forgejo). The installer must accept **any** public git URL, not just GitHub —
  chezmoi handles this natively.
- **Desktop:** **Sway (Wayland)** is canonical. The current i3 config is ported
  to sway as part of sub-project 2.
- **AUR:** included in v1.
- **Execution model:** **Hybrid (approach B).** The disk installer lays the
  foundation; a separate `kkjorsvik-setup` script does the heavy provisioning on
  first boot, as a normal user with networking up.

## Why approach B (hybrid)

The two hard parts — building AUR packages with `paru` and applying `chezmoi` —
both want to run as a normal user with real networking, not as root inside
`arch-chroot`. Running them at first boot instead of during install makes the
provisioning **idempotent and re-runnable** (fix a manifest, re-run; no
reinstall), which is also how we iterate while building it. Each piece (ISO,
installer, setup script, dotfiles repo) becomes independently testable. This is
the model Omakub / omarchy / ML4W converged on, and it is the most learnable.

## Architecture

Four components, built in this repo:

### 1. Package manifests

Plain-text, human-curated package lists. Baked into the ISO and copied onto the
installed system at `/usr/local/share/kkjorsvik/`.

- `packages.repo` — official-repo packages, installed via `pacman`.
- `packages.aur` — AUR packages, installed via `paru`.

Format: one package per line; `#` line comments; `# === Category ===` section
headers for readability (Core CLI · Dev languages · Cloud/DevOps ·
Desktop/Sway · Fonts · Apps). Blank lines and comments ignored by the installer.

This file is the "improve my system" artifact — deliberately curated, not a raw
dump of `pacman -Qqe`.

### 2. `kkjorsvik-setup` — first-boot provisioning script

Readable bash, installed to `/usr/local/bin/kkjorsvik-setup` on the target.
**Idempotent and re-runnable.** Run once after first login (also the iteration
loop during development). Stages:

1. **Preflight** — assert running as a normal user (not root), sudo works,
   network reachable. Abort early with a clear message otherwise.
2. **Repo packages** — `pacman -S --needed - < /usr/local/share/kkjorsvik/packages.repo`.
   `--needed` keeps re-runs safe.
3. **paru bootstrap** — if `paru` is absent, clone it from the AUR and
   `makepkg -si` as the current user (requires `base-devel`, included in
   `packages.repo`).
4. **AUR packages** — `paru -S --needed - < /usr/local/share/kkjorsvik/packages.aur`.
5. **chezmoi** — read the dotfiles URL from `/etc/kkjorsvik/dotfiles-url`; if
   present, `chezmoi init --apply <url>`. If the file is absent/empty, skip with
   a notice.
6. **Summary** — collect per-package failures and print them at the end; a
   single failing package must not abort the whole run.

`chezmoi` itself ships in `packages.repo` so it is present before stage 5.

### 3. Installer changes (`kkjorsvik-install`)

The installer pacstraps only the **irreducible minimum to boot to a sway login**
(base system, kernel, GRUB, NetworkManager, sway, greetd, polkit, a terminal).
Everything else — the full curated software set, including richer desktop tools —
comes from `packages.repo` via `kkjorsvik-setup`. This keeps the manifest the
single source of truth for "software"; the installer's list is just the bootable
floor. Overlap is harmless (`pacman --needed`).

- **New prompt:** dotfiles repo URL, defaulting to
  `https://git.kkjorsvik.com/kkjorsvik/dotfiles.git`; blank input skips dotfiles.
- Copy `packages.repo`, `packages.aur`, and `kkjorsvik-setup` into the target
  (`/usr/local/share/kkjorsvik/` and `/usr/local/bin/`).
- Write the chosen URL to `/etc/kkjorsvik/dotfiles-url` on the target.
- Keep a **minimal** `/etc/sway/config` fallback so the box boots into a usable
  sway *before* `kkjorsvik-setup` runs. Stop hand-copying the rich desktop
  configs (waybar/foot/fuzzel/mako) in the installer — chezmoi owns the user
  desktop config (`~/.config/...`) to avoid two sources of truth.
- End-of-install message instructs: log in as the new user and run
  `kkjorsvik-setup`. (Auto-run-on-first-boot is a possible later nicety; manual
  is safer for v1 because networking must be up.)

### 4. Curation (how the list gets decided)

During implementation, generate a **first-cut** `packages.repo` / `packages.aur`
from the current machine (`pacman -Qqen` / `-Qqem`) with proposed cuts applied:

- Collapse ~7 terminals and ~7 editors to a primary + fallback each.
- Trim the large nerd-font set to a handful.
- Drop build-only tooling (e.g. `archiso`, `qemu-full`) unless explicitly wanted.

The user reviews and edits the generated lists — that review **is** the curation
step. No silent inclusion/exclusion.

## Cross-cutting conventions

- Manifests on the installed system: `/usr/local/share/kkjorsvik/`.
- Dotfiles URL storage: `/etc/kkjorsvik/dotfiles-url`.
- `chezmoi` and `base-devel` belong in `packages.repo`; `paru` is bootstrapped
  from source (cannot come from `pacman`).
- chezmoi owns user desktop config; installer keeps only a minimal `/etc/sway`
  fallback.
- `kkjorsvik-setup` is manual-run on first boot for v1.

## Out of scope (this spec)

- The dotfiles repo contents and the i3→sway port (sub-project 2).
- Auto-running `kkjorsvik-setup` on first boot.
- Per-machine chezmoi templating / secrets.
- UEFI install path (installer remains BIOS/GPT + GRUB as today).

## Testing

- Build the ISO (`./build.sh`) and boot it in QEMU (`./test-qemu.sh`).
- Run `kkjorsvik-install` against a throwaway VM disk; verify manifests +
  `kkjorsvik-setup` land in the target and `/etc/kkjorsvik/dotfiles-url` is set.
- Boot the installed VM, run `kkjorsvik-setup`; verify repo packages, paru
  bootstrap, AUR packages, and `chezmoi apply` against the (initially near-empty)
  dotfiles repo. Re-run to confirm idempotency (no errors, no duplicate work).
- Verify a blank dotfiles URL cleanly skips the chezmoi stage.

## Build order

1. Sub-project 1 (this spec) — engine, testable against the empty dotfiles repo.
2. Sub-project 2 — harvest configs into the chezmoi repo + port i3→sway; the
   engine then consumes it via the URL.
