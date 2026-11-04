---
type: Decision
title: Replace Noctalia With Dux Shell As Nebula's Desktop Shell
description: 'nebula switched its integrated Wayland shell from Noctalia v5 to Dux Shell (ex-DankMaterialShell), from nixpkgs'' own module, as the only shell — Noctalia is disabled in place and the shared plumbing moved to a shell-agnostic module so switching back is a toggle.'
tags: [nixos, hyprland, desktop-shell]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-03T19:05:00-08:00 }
sources:
  - id: dux-shell-repo
    resource: https://github.com/duxlabs-dev/dux-shell
    title: Dux Shell repository (duxlabs-dev/dux-shell)
  - id: dux-shell-v2-release
    resource: https://github.com/duxlabs-dev/dux-shell/releases/tag/v2.0.0
    title: Dux Shell v2.0.0 release notes (rename from DankMaterialShell)
  - id: nixpkgs-dux-shell-module
    resource: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/wayland/dux-shell.nix
    title: nixpkgs `nixos/modules/programs/wayland/dux-shell.nix`
  - id: dux-issue-4103
    resource: https://github.com/duxlabs-dev/dux-shell/issues/4103
    title: 'Dux Shell #4103 — lock screen crash-loops when monitors power off (Hyprland 0.57)'
  - id: quickshell-4befab5
    resource: https://github.com/quickshell-mirror/quickshell/commit/4befab5bc
    title: 'Quickshell 4befab5 — hyprland/ipc: follow workspace id changes'
---

**Where:** [users-k-dux-shell](../modules/users-k-dux-shell.md),
[users-k-desktop-shell](../modules/users-k-desktop-shell.md),
[users-k-noctalia](../modules/users-k-noctalia.md), [hyprland](../modules/hyprland.md).

## Context

The goal was to try a different Hyprland shell from Noctalia. A survey on
2026-11-03 scored the live candidates for nebula specifically: Hyprland-git
(0.57) with the Lua config, NixOS without home-manager, plus security,
maintenance and efficiency. HyprPanel and Ax-Shell were archived; end-4 is
not NixOS-installable and owns the whole Hyprland config; Ambxst had the
weakest security (XOR-"encrypted" API keys, `curl | sh`) and incomplete Lua
support; ashell/Wayle are bars without a lock screen or launcher; Caelestia
is Hyprland-only with a home-manager-only flake module and a bus factor of
one. Dux Shell was the only alternative already in nixpkgs with a NixOS
module, natively Lua-aware on Hyprland 0.55+, and more featureful than
Noctalia (dock, polkit agent, idle handling, keybind editor) — at roughly
1.7× Noctalia's memory and on an unsandboxed Quickshell/QML
runtime.[^dux-shell-repo] It was renamed from DankMaterialShell at v2.0.0;
the CLI stays `dms`.[^dux-shell-v2-release]

## Decision

- **Only one shell, no switcher.** Both claim
  `org.freedesktop.Notifications` and paint the wallpaper, so they can't
  coexist. Noctalia's module stays in the tree behind `enable = false`; the
  Hyprland Lua was swapped outright (the previous wiring is in git and
  listed in `docs/dux-shell.md`).
- **Shared plumbing split out** into `desktop-shell.nix` (upower/ppd/bluetooth,
  swaync off, the bare-name PAM `login`, DDC/CI), so either shell gets it and
  a switch never has to move config.
- **nixpkgs' module, not upstream's flake.** `programs.dux-shell` from the
  pinned nixpkgs ships the systemd user unit and declarative plugins, and
  avoids a new flake input; it trails upstream by a release (2.0.0 vs
  2.1.0).[^nixpkgs-dux-shell-module]
- **Start via `dms.service`**, not `autostart.lua`: uwsm reaches
  `graphical-session.target`, the unit restarts on failure, and launched
  apps escape its cgroup via `systemd-run --scope`.
- **Only the colors fragment** (`require("dms.colors")`, searchpath-guarded)
  is included; nebula's own Lua keeps monitors, layout, input, binds and
  window rules. `dms setup` and Settings "Setup" banners are off-limits
  because they write `hyprland.lua`, a stow symlink into the repo.
- **Dux's polkit agent wins**: `hyprpolkitagent` isn't started while Dux is
  enabled, since a session takes one agent and the two would race.

## Consequences

- Lock auth needs no config: Dux's "Auto" mode copies nebula's bare-name
  `/etc/pam.d/login` into `~/.local/state/dms/pam/`, inheriting the glibc-bump
  fix.
- Watch: the open lock crash-loop when outputs power off on Hyprland
  0.57[^dux-issue-4103] (session stays locked), and nixpkgs' quickshell 0.3.2
  predating the `changeworkspaceid` fix[^quickshell-4befab5] — if the
  workspace bar keeps stale ids, override `programs.dux-shell.quickshell.package`
  with a quickshell git build.
- Dux settings (`~/.config/dms/settings.json`) are not yet snapshot-synced
  into `config/` the way Noctalia's were; the icon-theme setting must stay
  "System Default" because it `sed -i`s the stow-linked GTK `settings.ini`.
- Landed in the commit that adds this record.

[^dux-shell-repo]: Dux Shell repository (duxlabs-dev/dux-shell)
[^dux-shell-v2-release]: Dux Shell v2.0.0 release notes (rename from DankMaterialShell)
[^nixpkgs-dux-shell-module]: nixpkgs `nixos/modules/programs/wayland/dux-shell.nix`
[^dux-issue-4103]: Dux Shell #4103 — lock screen crash-loops when monitors power off (Hyprland 0.57)
[^quickshell-4befab5]: Quickshell 4befab5 — hyprland/ipc: follow workspace id changes
