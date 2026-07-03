---
type: NixOS Module
title: Gtk Dark
description: 'Forces GTK apps to Adwaita''s dark variant via one session variable (GTK_THEME=Adwaita:dark) — a bare Hyprland session has no settings daemon to broadcast prefer-dark.'
resource: modules/nixos/gtk-dark.nix
tags: [nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

One line of substance: `environment.sessionVariables.GTK_THEME =
"Adwaita:dark"`. A bare wlroots/Hyprland session has no settings daemon
broadcasting `color-scheme = prefer-dark`, so GTK apps (including
LibreOffice's gtk3 VCL plugin) default to light and override in-app "Dark"
choices back to light. The `gtk-application-prefer-dark-theme` hint alone
can't help either — no separate Adwaita-dark theme directory is installed for
it to resolve to. Explicitly selecting the `:dark` variant, which is compiled
into GTK itself, is the reliable lever. Set as a session variable so every
launch path inherits it; requires a re-login to take effect.

Mounted ungated on every NixOS host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/gtk-dark.nix`](../../modules/nixos/gtk-dark.nix)
- Manual: [`docs/libreoffice.md`](../../docs/libreoffice.md)
