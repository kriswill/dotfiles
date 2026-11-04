---
type: NixOS Module
title: Users K Noctalia
description: 'Installs the Noctalia v5 desktop shell (native C++ Wayland binary) for user k with its tomato + noctalia-config snapshot tooling — disabled behind a local `enable = false` since 2026-11-03, when Dux Shell replaced it.'
resource: modules/hosts/nebula/users/k/noctalia.nix
tags: [nixos-module, host-specific]
generated: { by: okflight/0.4.0, at: 2026-07-03T12:00:00-07:00 }
---

**Disabled since 2026-11-03.** [Dux Shell](users-k-dux-shell.md) is nebula's
shell now ([decision](../decisions/dux-shell-replaces-noctalia.md)). The file
is kept whole behind a top-level `enable = false` + `lib.mkIf` so switching
back is cheap: flip it, disable Dux, restore the Lua wiring (steps in
[`docs/dux-shell.md`](../../docs/dux-shell.md)). The shell-agnostic parts it
used to carry — upower/power-profiles-daemon/bluetooth, swaync off, the
bare-name `/etc/pam.d/login`, DDC/CI (i2c + ddcutil) — moved to
[users-k-desktop-shell](users-k-desktop-shell.md) and stay on for either
shell. Everything below describes Noctalia as it ran until then.

Noctalia shell (<https://noctalia.dev>) for user `k` under
[Hyprland](hyprland.md). Noctalia v5 is a NATIVE C++ Wayland desktop shell
(bar, launcher, control centre, lock screen, notifications) built directly on
Wayland + OpenGL ES — NOT Quickshell/QML (that was v4). It ships as a single
self-contained `noctalia` binary from the `noctalia` flake input (pinned in
flake.nix, following our nixpkgs). v5.0.0, verified 2026-06-19. NOT
home-manager.

Dependency cleanup (2026-06-19): v5 needs no extra runtime tools in this user
package list. The old v4 helpers (matugen, cava, cliphist, wl-clipboard,
brightnessctl) were dropped because the v5 binary doesn't reference them — it
vendors Material Color Utilities (palette generation, no matugen), uses
PipeWire/wpctl for the audio visualiser (no cava), and has native clipboard
history and backlight/ddcutil brightness. cliphist + wl-clipboard +
brightnessctl stay available system-wide (configuration.nix systemPackages +
snowglobe's desktop module) for the Hyprland keybinds that use them, so
dropping them here is a no-op for those. External-monitor brightness also
needs `[brightness].enable_ddcutil = true` in settings.toml.

Also installed: `pkgs.tomato` (TOML get/set, used by the Hyprland toggle-gaps
keybind to flip `[shell.screen_corners].enabled`) and `pkgs.noctalia-config`
(settings.toml snapshot/restore into `config/noctalia/`, plaintext — per the
[snapshot-synced configs pattern](../patterns/snapshot-synced-configs.md),
like [users-k-helium](users-k-helium.md)'s helium-config). The
Hyprland-side wiring (autostart + recommended blur layerrule + keybinds)
lived in the stow-managed Lua config, `home/hyprland/.config/hypr/` —
Noctalia was launched via `noctalia --daemon` on hyprland.start and driven
with `noctalia msg <command>` from binds.

Module collision (2026-08-02): nixos-unstable grew its own
`programs.noctalia` module, colliding with the upstream noctalia-shell flake
module snowglobe-factory's `mkNixosHost` imported into every host; this file
carried `disabledModules = [ "programs/wayland/noctalia.nix" ]` until commit
`51db6bf` (2026-08-16) dropped it — see the
[decision record](../decisions/noctalia-flake-module-over-nixpkgs.md).

Notification daemon and lock screen (2026-10-02): Noctalia owns
`org.freedesktop.Notifications` (so swaync is off) and authenticates through
PAM service `login` (so linux-pam's modules get bare names to survive glibc
bumps). Both now live in [users-k-desktop-shell](users-k-desktop-shell.md).

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

The capture service sets `restartIfChanged = false` so a switch never waits out its debounce, and `TimeoutStartSec = "2min"` so a hung capture can't stay activating forever — see [user oneshots skip switch restart](../decisions/user-oneshots-skip-switch-restart.md).

## Source

- Module: [`modules/hosts/nebula/users/k/noctalia.nix`](../../modules/hosts/nebula/users/k/noctalia.nix)
- Manual: [`docs/noctalia.md`](../../docs/noctalia.md)
