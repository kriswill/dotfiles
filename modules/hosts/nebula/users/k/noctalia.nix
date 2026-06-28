# Noctalia shell (https://noctalia.dev) for user `k` under Hyprland.
#
# Noctalia v5 is a NATIVE C++ Wayland desktop shell (bar, launcher, control
# centre, lock screen, notifications) built directly on Wayland + OpenGL ES —
# NOT Quickshell/QML (that was v4). It ships as a single self-contained
# `noctalia` binary from the `noctalia` flake input (pinned in flake.nix,
# following our nixpkgs). See docs/noctalia.md. v5.0.0, verified 2026-06-19.
#
# v5 needs no extra runtime tools in this user package list. The old v4 helpers
# (matugen, cava, cliphist, wl-clipboard, brightnessctl) were dropped on
# 2026-06-19 (see docs/noctalia.md "Recommended cleanup") because the v5 binary
# doesn't reference them: it vendors Material Color Utilities (palette generation,
# no matugen), uses PipeWire/wpctl for the audio visualiser (no cava), and has
# native clipboard history and backlight/ddcutil brightness. cliphist +
# wl-clipboard + brightnessctl stay available system-wide (configuration.nix
# systemPackages + snowglobe's desktop module) for the Hyprland keybinds
# that use them, so dropping them here is a no-op for those.
#
# EXTERNAL monitor brightness (2026-06-19): nebula's DP monitors have no kernel
# backlight, so brightness only works over DDC/CI on the I2C bus. We add
# pkgs.ddcutil + `hardware.i2c.enable` (loads i2c-dev declaratively, creates the
# i2c group + udev rules) and put k in the i2c group; then set
# [brightness].enable_ddcutil = true in settings.toml. (k already had per-session
# ACL access to /dev/i2c-*, so the group is the durable fallback.) Whether DDC/CI
# actually works over the NVIDIA i2c buses is the real unknown — test with
# `ddcutil detect`.
#
# This installs it for `k` and enables the system services the shell's widgets
# read. The Hyprland-side wiring (autostart + recommended blur layerrule +
# keybinds) lives in the stow-managed Lua config, home/hyprland/.config/hypr/
# hyprland.lua — Noctalia is launched via `noctalia --daemon` on hyprland.start
# and driven with `noctalia msg <command>` from binds. NOT home-manager.
{
  configurations.nixos.nebula.module =
    {
      pkgs,
      inputs,
      ...
    }:
    {
      # Background daemons the shell surfaces (battery/power, bluetooth, power
      # profiles). networking.networkmanager is already on (k is in the
      # networkmanager group). Recommended by docs.noctalia.dev for full
      # functionality; harmless on this desktop where unused.
      services.upower.enable = true;
      services.power-profiles-daemon.enable = true;
      hardware.bluetooth.enable = true;

      # DDC/CI for external-monitor brightness (Noctalia's ddcutil backend).
      # Loads the i2c-dev module, creates the i2c group, and installs the udev
      # rules that group-own /dev/i2c-*. Pair with [brightness].enable_ddcutil.
      hardware.i2c.enable = true;
      users.users.k.extraGroups = [ "i2c" ];

      users.users.k.packages = [
        inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default

        # External-monitor brightness over DDC/CI (no kernel backlight on DP).
        # Used by Noctalia when [brightness].enable_ddcutil = true.
        pkgs.ddcutil

        # tomato — comment/format-preserving TOML get/set CLI (Rust, toml_edit).
        # The Hyprland "toggle gaps" keybind (home/hyprland/.config/hypr/scripts/
        # toggle-gaps.sh) uses it to flip [shell.screen_corners].enabled in
        # settings.toml in lockstep with the gaps toggle, then `noctalia msg
        # config-reload`. Built from the `tomato` flake input; see
        # packages/tomato.nix.
        pkgs.tomato

        # noctalia-config — snapshot/restore settings.toml into the dotfiles repo
        # (config/noctalia/settings.toml) without symlinking the live file.
        # noctalia rewrites settings.toml via atomic rename, which breaks a stow
        # symlink on the first GUI save; and a dir-symlink would put the whole
        # state dir (clipboard secrets, nested plugin .git) in the repo and let
        # routine git ops clobber the live config. So we sync explicitly:
        # `noctalia-config capture` after GUI edits, `restore` on a fresh machine.
        # See packages/noctalia-config.nix and docs/noctalia.md.
        pkgs.noctalia-config
      ];
    };
}
