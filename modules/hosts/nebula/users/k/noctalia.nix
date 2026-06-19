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
# systemPackages + snowglobe's desktop module) for the niri/Hyprland keybinds
# that use them, so dropping them here is a no-op for those. To drive EXTERNAL
# monitor brightness from Noctalia, add pkgs.ddcutil and set
# [brightness].enable_ddcutil = true (also needs i2c-dev + the i2c group).
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

      users.users.k.packages = [
        inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}
