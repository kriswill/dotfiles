---
type: NixOS Module
title: Hyprland
description: Enables Hyprland directly (programs.hyprland + withUWSM) instead of snowglobe-lib.desktop.hyprland — dodging its force-enabled hyprlock/kitty/dolphin — and asserts the shared snowglobe desktop layer plus fuzzel formerly implied by niri.
resource: modules/hosts/nebula/hyprland.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

Enables the Hyprland desktop **directly** (`programs.hyprland.enable` +
`withUWSM = true`, which provides the `hyprland-uwsm` session used as
`defaultSession` in [configuration](configuration.md)) rather than via
`snowglobe-lib.desktop.hyprland.enable`. That snowglobe module's only wanted
contribution is `programs.hyprland` + uwsm; it also force-enables hyprlock
(which auto-enables hypridle), kitty, dolphin, and hyprlauncher — none used
here (ghostty terminal, fuzzel/Noctalia launcher, Noctalia lock), and
hyprlock repeatedly broke the build whenever the hyprland flake's hyprutils
overlay outpaced nixpkgs. See the manual.

Since niri was removed, nebula has no other desktop, so this file also
asserts the shared snowglobe desktop layer that niri used to pull in:
`snowglobe-lib.system.hasDesktop` plus `snowglobe-lib.desktop.enable` /
`installWaylandDeps` (xdg portals, pipewire, bluetooth,
grim/slurp/wl-clipboard, swaync, fonts, the [ly](ly.md) greeter,
`NIXOS_OZONE_WL`), and `programs.fuzzel.enable` for the Hyprland keybind
launcher.

Note this file sets **no** NVIDIA-specific env vars — driver selection lives
in [configuration](configuration.md) (`hardware.nvidia.package = production`)
and the GPU metadata in the [nebula](../hosts/nebula.md) registry entry
(`gpu-vendors = ["nvidia"]`). The user-side Hyprland config is the
stow-tracked Lua tree under `home/hyprland/`.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/hyprland.nix`](../../modules/hosts/nebula/hyprland.nix)
- Manual: [`docs/hyprland.md`](../../docs/hyprland.md)
- Manual: [`docs/hdr-hyprland-june-2026.md`](../../docs/hdr-hyprland-june-2026.md)
