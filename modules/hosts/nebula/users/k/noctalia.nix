# Noctalia shell (https://noctalia.dev) for user `k` under Hyprland.
#
# Noctalia is a Quickshell-based Wayland desktop shell (bar, launcher, control
# centre, lock screen, notifications). It ships as a single self-contained
# `noctalia` binary from the `noctalia` flake input (pinned in flake.nix,
# following our nixpkgs). v5, verified 2026-06-16.
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
