---
type: NixOS Module
title: Users K Noctalia
description: Installs the Noctalia v5 desktop shell (native C++ Wayland binary) for user k plus its support tooling — ddcutil + i2c for DDC/CI monitor brightness, tomato, noctalia-config snapshots — and the upower/power-profiles-daemon/bluetooth services its widgets read.
resource: modules/hosts/nebula/users/k/noctalia.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

Noctalia shell (<https://noctalia.dev>) for user `k` under
[Hyprland](hyprland.md). Noctalia v5 is a NATIVE C++ Wayland desktop shell
(bar, launcher, control centre, lock screen, notifications) built directly on
Wayland + OpenGL ES — NOT Quickshell/QML (that was v4). It ships as a single
self-contained `noctalia` binary from the `noctalia` flake input (pinned in
flake.nix, following our nixpkgs). v5.0.0, verified 2026-06-19. This file
installs it for `k` and enables the system services the shell's widgets read
(upower, power-profiles-daemon, bluetooth). NOT home-manager.

Dependency cleanup (2026-06-19): v5 needs no extra runtime tools in this user
package list. The old v4 helpers (matugen, cava, cliphist, wl-clipboard,
brightnessctl) were dropped because the v5 binary doesn't reference them — it
vendors Material Color Utilities (palette generation, no matugen), uses
PipeWire/wpctl for the audio visualiser (no cava), and has native clipboard
history and backlight/ddcutil brightness. cliphist + wl-clipboard +
brightnessctl stay available system-wide (configuration.nix systemPackages +
snowglobe's desktop module) for the Hyprland keybinds that use them, so
dropping them here is a no-op for those.

External monitor brightness (2026-06-19): nebula's DP monitors have no kernel
backlight, so brightness only works over DDC/CI on the I2C bus. We add
`pkgs.ddcutil` + `hardware.i2c.enable` (loads i2c-dev declaratively, creates
the i2c group + udev rules) and put `k` in the `i2c` group; then set
`[brightness].enable_ddcutil = true` in settings.toml. (`k` already had
per-session ACL access to `/dev/i2c-*`, so the group is the durable
fallback.) Whether DDC/CI actually works over the NVIDIA i2c buses is the
real unknown — test with `ddcutil detect`.

Also installed: `pkgs.tomato` (TOML get/set, used by the Hyprland toggle-gaps
keybind to flip `[shell.screen_corners].enabled`) and `pkgs.noctalia-config`
(settings.toml snapshot/restore into `config/noctalia/`, plaintext — per the
[snapshot-synced configs pattern](../patterns/snapshot-synced-configs.md),
like [users-k-helium](users-k-helium.md)'s helium-config). The
Hyprland-side wiring (autostart + recommended blur layerrule + keybinds)
lives in the stow-managed Lua config,
`home/hyprland/.config/hypr/hyprland.lua` — Noctalia is launched via
`noctalia --daemon` on hyprland.start and driven with `noctalia msg
<command>` from binds.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/users/k/noctalia.nix`](../../modules/hosts/nebula/users/k/noctalia.nix)
- Manual: [`docs/noctalia.md`](../../docs/noctalia.md)
