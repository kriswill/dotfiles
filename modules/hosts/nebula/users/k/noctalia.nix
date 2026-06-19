# Noctalia shell (https://noctalia.dev) for user `k` under Hyprland.
#
# Noctalia v5 is a NATIVE C++ Wayland desktop shell (bar, launcher, control
# centre, lock screen, notifications) built directly on Wayland + OpenGL ES —
# NOT Quickshell/QML (that was v4). It ships as a single self-contained
# `noctalia` binary from the `noctalia` flake input (pinned in flake.nix,
# following our nixpkgs). See docs/noctalia.md. v5.0.0, verified 2026-06-19.
#
# NOTE (see docs/noctalia.md "Recommended cleanup"): on v5 the matugen and cava
# packages below are vestigial v4 deps — v5 vendors Material Color Utilities for
# palette generation and uses PipeWire/wpctl for the audio visualiser; neither
# `matugen` nor `cava` is referenced by the v5 binary. Likewise cliphist /
# wl-clipboard / brightnessctl have native v5 equivalents. Left in place for now;
# safe to trim after confirming behaviour.
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

        # Runtime tools Noctalia shells out to. cliphist is also installed
        # system-wide; listing it here is harmless (nix dedups) and keeps the
        # shell's dependencies self-documented.
        pkgs.brightnessctl # screen/keyboard brightness slider
        pkgs.cliphist # clipboard history panel
        pkgs.wl-clipboard # wl-copy/wl-paste, used by the clipboard panel
        pkgs.matugen # Material-You palette generation from wallpaper
        pkgs.cava # audio visualiser widget
      ];
    };
}
