---
type: NixOS Module
title: Users K Dux Shell
description: 'Enables nixpkgs'' programs.dux-shell — Dux Shell (formerly DankMaterialShell), a Quickshell/QML desktop shell with a Go `dms` daemon — as nebula''s shell under Hyprland, started by its dms.service user unit, with Dux''s own polkit agent replacing hyprpolkitagent.'
resource: modules/hosts/nebula/users/k/dux-shell.nix
tags: [nixos-module, host-specific]
generated: { by: claude-code/opus-5.5, at: 2026-11-03T19:05:00-08:00 }
sources:
  - id: nixpkgs-dux-shell-module
    resource: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/wayland/dux-shell.nix
    title: nixpkgs `nixos/modules/programs/wayland/dux-shell.nix`
  - id: nixos-options-dux-shell
    resource: https://search.nixos.org/options?channel=unstable&query=programs.dux-shell
    title: NixOS options search — programs.dux-shell
  - id: dux-docs-compositors
    resource: https://github.com/duxlabs-dev/dux-docs/blob/master/versioned_docs/version-2.0/dms/compositors.mdx
    title: Dux Shell 2.0 docs — compositor (Hyprland Lua) configuration
  - id: dux-shell-manual
    resource: ../../docs/dux-shell.md
    title: docs/dux-shell.md — nebula's Dux Shell manual
---

nebula's desktop shell since 2026-11-03, replacing
[Noctalia](users-k-noctalia.md) (kept, disabled) — see the
[decision](../decisions/dux-shell-replaces-noctalia.md). It is nixpkgs'
`dux-shell` 2.0.0 on `quickshell` 0.3.2 through nixpkgs' own module, which
also adds matugen + cava to the system PATH and mkDefaults
accounts-daemon / i2c / graphics on.[^nixpkgs-dux-shell-module] The project
was renamed from DankMaterialShell at v2.0.0, but the CLI is still `dms`
and the unit `dms.service`.[^nixos-options-dux-shell]

Wiring worth knowing before touching it (full detail in the
manual[^dux-shell-manual]):

- **Startup is the user unit, not Hyprland.** `dms.service` is WantedBy
  `graphical-session.target`, which nebula's uwsm session reaches; launched
  apps get their own `systemd-run --scope`, so a shell restart doesn't kill
  them.
- **One polkit agent.** Dux registers its own, so this file forces
  `hyprpolkitagent`'s `wantedBy` (set in
  [nebula's configuration](../hosts/nebula.md)) to `[]`; disabling Dux
  restores it.
- **Hyprland side lives in the stow tree** ([hyprland](hyprland.md)): binds
  call `dms ipc call …` / `dms screenshot`, and `hyprland.lua` requires only
  the generated `dms/colors.lua`, behind a `package.searchpath` guard. Dux's
  other fragments (outputs, layout, input, binds, windowrules) are left out
  because nebula's own Lua owns those.[^dux-docs-compositors]
- **Don't let Dux edit the config.** `dms setup` replaces `hyprland.lua` (a
  [stow](../patterns/stow-tree.md) symlink), the Settings "Setup"
  banners append `require` lines into the repo copy, and the icon-theme
  setting `sed -i`s the stow-linked GTK `settings.ini` (breaking the link).
- **Shared plumbing is elsewhere:** swaync off, the bare-name PAM fix that
  Dux's lock auth copies, upower/ppd/bluetooth and DDC/CI live in
  [users-k-desktop-shell](users-k-desktop-shell.md).

Settings (`~/.config/dms/settings.json`) are not snapshot-synced yet, unlike
Noctalia's ([snapshot-synced configs](../patterns/snapshot-synced-configs.md)).

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/users/k/dux-shell.nix`](../../modules/hosts/nebula/users/k/dux-shell.nix)
- Manual: [`docs/dux-shell.md`](../../docs/dux-shell.md)

[^nixpkgs-dux-shell-module]: nixpkgs `nixos/modules/programs/wayland/dux-shell.nix`
[^nixos-options-dux-shell]: NixOS options search — programs.dux-shell
[^dux-docs-compositors]: Dux Shell 2.0 docs — compositor (Hyprland Lua) configuration
[^dux-shell-manual]: docs/dux-shell.md — nebula's Dux Shell manual
