# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A NixOS flake that defines the system configuration for the host `nebula` (AMD CPU, NVIDIA GPU, UEFI). It is built on top of [`snowglobe-lib`](https://codeberg.org/earthgman/snowglobe-lib), which provides the host builder (`slib.mkNixosHost`), the `snowglobe-lib.*` module options (profiles, desktop, etc.), and the `import-tree` auto-importer. Most of the actual functionality comes from `snowglobe-lib`; this repo is mostly host-specific glue.

## Manuals (`docs/`)

`docs/` holds task-focused reference manuals — researched, verified against this
machine, and written for *your* (Claude's) reuse, not as user-facing docs.
**Consult the relevant manual before working on its topic**, and keep it
current as part of doing the work.

| Manual | Covers |
|---|---|
| [`docs/hyprland.md`](docs/hyprland.md) | Hyprland config (0.55 Lua API + legacy `.conf` translation), binds, rules, layouts, NVIDIA, and nebula-specific gotchas |
| [`docs/hdr-hyprland-june-2026.md`](docs/hdr-hyprland-june-2026.md) | **HDR under Hyprland (current session)** — `cm`/`bitdepth` monitor config, how to tell if HDR is active, live tuning, getting Proton games into HDR |
| [`docs/hdr-niri-june-2026.md`](docs/hdr-niri-june-2026.md) | HDR under niri (historical — niri has no color-management protocol; superseded by the Hyprland doc for the current session) |
| [`docs/bootloader-issues-jun-06.md`](docs/bootloader-issues-jun-06.md) | boot-failure investigation notes |
| [`docs/libreoffice.md`](docs/libreoffice.md) | LibreOffice notes |

**Maintaining them:**

- Each manual leads with the **exact version/state it was verified against** and
  ends with **dated sources**. When you touch a topic, re-verify the facts that
  matter (`hyprctl version`, `hyprctl getoption`, what's actually installed) and
  update the manual — *correct or delete stale claims rather than appending
  contradictions.*
- Every manual gets a **"Learned behaviours & workarounds"** section. When you
  hit a non-obvious gotcha, a footgun, or a fix that took digging, record it
  there (dated, with how it was observed) so the next session starts ahead.
- Prefer **machine-verified** statements over wiki/upstream claims when they
  disagree — note the disagreement. Cite official docs in the Sources list.
- New manual → add a row to the table above so it's discoverable.

## Where this lives

The nebula host config is the **`nebula-snowglobe`** branch of the personal dotfiles repo, cloned to `/home/k/src/github/kriswill/dotfiles` (origin: `github.com/kriswill/dotfiles`). It's a *bare/orphan* branch — independent history from `main` (which holds the cross-host dotfiles). The repo follows a host-then-path layout (`~/src/github/<owner>/<repo>`) mirroring the same convention used on the user's Mac.

Two symlinks point at that checkout for convenience:

```
/etc/nixos -> /home/k/src/dotfiles -> github/kriswill/dotfiles  (on branch nebula-snowglobe)
```

Make all edits and git operations in the real checkout (`/home/k/src/github/kriswill/dotfiles`); the symlinks just make the flake reachable at the conventional `~/src/dotfiles` / `/etc/nixos` paths.

**Rebuild gotcha:** nix's `--flake <path>` does *not* follow a path that is itself a symlink, so `--flake /etc/nixos#nebula` and `--flake ~/src/dotfiles#nebula` both fail with "not a flake (not a directory)". `cd` into the dir first so `.` resolves via the (canonicalized) cwd — that's why the commands below use `.#nebula` after entering the dir. Passing the real path `~/src/github/kriswill/dotfiles#nebula` also works.

## Common commands

Run after `cd /etc/nixos` (or `cd ~/src/dotfiles`) so `.` resolves to the real checkout:

```sh
# Rebuild and switch the running system
sudo nixos-rebuild switch --flake .#nebula

# Build for next boot without activating
sudo nixos-rebuild boot --flake .#nebula

# Dry build (no activation, no GC root) — quickest way to typecheck a change
nixos-rebuild build --flake .#nebula

# Update flake inputs (nixpkgs is pinned via snowglobe-lib/nixpkgs)
nix flake update

# Evaluate the flake / surface evaluation errors
nix flake check
```

Secrets are sops-nix encrypted with the `nebula` age key (see `.sops.yaml`). Edit with `sops nixosConfigurations/nebula/secrets.yaml`.

## Architecture

The flake's `outputs` are wired so that almost everything flows through `snowglobe-lib`:

- **`flake.nix`** — pins `snowglobe-lib` and follows its `nixpkgs` and `import-tree` inputs (do not add a second `nixpkgs` input without `inputs.nixpkgs.follows = "nixpkgs"` to avoid duplicating the store). Exposes `nixosConfigurations`, `nixosModules.default`, `overlays`, and per-system `packages`.
- **`nixosConfigurations/default.nix`** — declares hosts via `slib.mkNixosHost`. Each host gets a `configDir` (e.g. `./nebula`) which `mkNixosHost` recursively imports, plus `modules = [ outputs.nixosModules.default ]` so every host pulls in the shared module set.
- **`nixosModules/default/`** — the shared module tree. `flake.nix` wraps this directory with `import-tree`, so **any `.nix` file added under here is auto-imported** — there's no central `imports = [ ... ]` list to update. `keyring.nix` is special: the installer reads it to look up SSH/age/openpgp keys by short name (e.g. `config.keyring.ssh.k`).
- **`nixosConfigurations/nebula/`** — host-specific config. `configuration.nix` is where the host's `snowglobe-lib.profiles.*` (`hacker-mode`, `gaming`, `office`, `harden`, `nix-tools`, `hardware-tools`) and `snowglobe-lib.desktop.niri` are toggled. `disko.nix` declares partitioning (single-disk, ext4 root, vfat ESP). `hardware-configuration.nix` is generated — don't hand-edit. `users/k/` defines the primary user; its password is sops-managed.
- **`overlays/default.nix`** — exposes overlays. The `my-packages` overlay re-imports `packages/` so custom derivations land in `pkgs`. `mkNixosHost` and the packages output both apply all overlays via `builtins.attrValues outputs.overlays`.
- **`packages/default.nix`** — where custom `pkgs.callPackage` derivations go (currently `helium`, the browser, and `dots-adopt`, the dotfiles capture helper).

When adding shared functionality, drop a new file under `nixosModules/default/` (it will be auto-imported). When adding host-specific config, edit files under `nixosConfigurations/nebula/`. New custom packages go in `packages/` and become available as `pkgs.<name>` via the overlay.

## Dotfiles (GNU Stow)

User-level configs under `~/.config` that aren't nix-managed (niri, ghostty, kanshi, …) are tracked here via [GNU Stow](https://www.gnu.org/software/stow/), kept separate from the NixOS modules:

- **`home/`** — the stow tree. Each top-level dir is one stow *package* whose contents mirror `$HOME`, e.g. `home/niri/.config/niri/config.kdl` → `~/.config/niri/config.kdl`. This dir is invisible to flake evaluation (`import-tree` only scans `nixosModules/default/`).
- **`nixosModules/default/dotfiles-stow.nix`** — auto-imported activation module. On every `nixos-rebuild switch` it runs `stow --no-folding --restow` for **every** package under `home/` (auto-discovered) as user `k`, so symlinks are (re)created idempotently. It operates on the live repo path (`/home/k/src/dotfiles/home`), never a `/nix/store` copy, so links stay stable and editable. A conflict on one package logs a warning and is skipped — it never fails the rebuild. The module also puts `stow` and `dots-adopt` on `PATH`.
- **`--no-folding`** is deliberate: `~/.config/<app>` stays a real directory with only the tracked files symlinked, so app-generated siblings don't leak into the repo.

To **capture a new config** into the repo (move it in + replace the original with a symlink + stage it):

```sh
dots-adopt <pkg> <relpath-under-$HOME>      # e.g. dots-adopt waybar .config/waybar/config
```

To **pull live edits** of an already-tracked file back into the repo (overwrites the repo copy with the on-disk one), use stow's own adopt:

```sh
stow -d ~/src/dotfiles/home -t ~ --no-folding --adopt <pkg>
```
