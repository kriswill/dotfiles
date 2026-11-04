# Noctalia shell (https://noctalia.dev) for user `k` under Hyprland.
#
# DISABLED since 2026-11-03: Dux Shell is nebula's desktop shell
# (dux-shell.nix). This module is kept whole so switching back is cheap: set
# `enable = true` below, set `programs.dux-shell.enable = false` in
# dux-shell.nix, and restore the Noctalia wiring in the stow-managed Hyprland
# Lua (docs/dux-shell.md → "Switching back to Noctalia"). The shell-agnostic
# plumbing (upower/ppd/bluetooth, swaync off, the bare-name PAM fix, DDC/CI)
# moved to desktop-shell.nix and stays on for either shell.
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
# EXTERNAL monitor brightness: DDC/CI is enabled in desktop-shell.nix; Noctalia
# also needs [brightness].enable_ddcutil = true in settings.toml.
#
# The Hyprland-side wiring (autostart + recommended blur layerrule + keybinds)
# lives in the stow-managed Lua config, home/hyprland/.config/hypr/ — Noctalia
# is launched via `noctalia --daemon` on hyprland.start and driven with
# `noctalia msg <command>` from binds. NOT home-manager.
let
  # Off while Dux Shell is the shell (see the header). Only one integrated shell
  # may run: both claim org.freedesktop.Notifications and paint the wallpaper.
  enable = false;
in
{
  configurations.nixos.nebula.module =
    {
      lib,
      pkgs,
      inputs,
      ...
    }:
    {
      config = lib.mkIf enable {
        users.users.k.packages = [
          inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default

          # tomato — comment/format-preserving TOML get/set CLI (Rust, toml_edit).
          # The Hyprland "toggle gaps" keybind (toggleGaps in
          # home/hyprland/.config/hypr/keybindings.lua, formerly
          # scripts/toggle-gaps.sh) uses it to flip [shell.screen_corners].enabled
          # in settings.toml in lockstep with the gaps toggle, then `noctalia msg
          # config-reload`. Built from the `tomato` flake input; see
          # pkgs/tomato.nix.
          pkgs.tomato

          # noctalia-config — snapshot/restore settings.toml into the dotfiles repo (see
          # the auto-capture path unit below)
          # (config/noctalia/settings.toml) without symlinking the live file.
          # noctalia rewrites settings.toml via atomic rename, which breaks a stow
          # symlink on the first GUI save; and a dir-symlink would put the whole
          # state dir (clipboard secrets, nested plugin .git) in the repo and let
          # routine git ops clobber the live config. So we sync explicitly:
          # `noctalia-config capture` after GUI edits, `restore` on a fresh machine.
          # See pkgs/noctalia-config.nix and docs/noctalia.md.
          pkgs.noctalia-config
        ];

        # Auto-capture: noctalia saves settings.toml via atomic rename; a path
        # unit runs `noctalia-config capture` after each save (repo working tree
        # only — review + commit stays manual). Debounce is the sleep (path
        # triggers are suppressed while the service runs); no TriggerLimit* —
        # exceeding it would fail the path unit and stop the watching.
        # restartIfChanged = false: don't make a switch wait out the sleep.
        # TimeoutStartSec: a oneshot's default is infinity; bound a hung capture.
        systemd.user.paths.noctalia-config-capture = {
          wantedBy = [ "paths.target" ];
          pathConfig.PathChanged = "%h/.local/state/noctalia/settings.toml";
        };
        systemd.user.services.noctalia-config-capture = {
          restartIfChanged = false;
          serviceConfig.Type = "oneshot";
          serviceConfig.TimeoutStartSec = "2min";
          serviceConfig.ExecStart = pkgs.writeShellScript "noctalia-config-capture" ''
            sleep 5
            exec ${lib.getExe pkgs.noctalia-config} capture
          '';
        };
      };
    };
}
