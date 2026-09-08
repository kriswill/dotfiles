---
type: NixOS Module
title: Localsearch
description: 'Enables services.gnome.localsearch (the tracker-miners package''s new name), registering its D-Bus service file so GTK file managers can activate the Tracker3 filesystem indexer on demand instead of failing to find it.'
resource: modules/nixos/localsearch.nix
tags: [nixos-module]
generated: { by: okflight/0.4.0, at: 2026-07-19T02:38:28+00:00 }
sources:
  - id: nixos-modules-services-desktops-gnome-localsearc
    resource: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/desktops/gnome/localsearch.nix
    title: nixos/modules/services/desktops/gnome/localsearch.nix
  - id: gnome-localsearch
    resource: https://gitlab.gnome.org/GNOME/localsearch
    title: GNOME LocalSearch
---

One line of substance: `services.gnome.localsearch.enable = true`, which
installs `pkgs.localsearch` and adds its package to `services.dbus.packages`
+ `systemd.packages` — the part that actually matters here, since it's what
makes `org.freedesktop.Tracker3.Miner.Files` D-Bus-activatable. Without it,
Nautilus's own attempt to connect fails with "the name is not activatable".

Mounted ungated on every NixOS host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md). Part of the same
fix as [gtk-dark](gtk-dark.md)'s dconf addition — see the
[decision record](../decisions/nautilus-dbus-warnings.md).

## Source

- Module: [`modules/nixos/localsearch.nix`](../../modules/nixos/localsearch.nix)
