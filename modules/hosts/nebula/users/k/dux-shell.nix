# Dux Shell (https://duxlabs.dev) — nebula's desktop shell since 2026-11-03,
# replacing Noctalia (noctalia.nix, kept but disabled). Formerly
# DankMaterialShell ("DMS"): renamed when the project moved to Dux Labs
# (v2.0.0, 2026-10-20), but the CLI is still `dms` and the unit `dms.service`.
#
# Quickshell/QML UI + a Go `dms` daemon/CLI, straight from nixpkgs (dux-shell
# 2.0.0 on quickshell 0.3.2) through nixpkgs' own NixOS module,
# programs.dux-shell — which also puts matugen + cava on the system PATH and
# turns on accounts-daemon/i2c/graphics. The plumbing shared with any shell
# (upower/ppd/bluetooth, swaync off, the bare-name PAM fix, DDC/CI) lives in
# desktop-shell.nix.
#
# Startup: the module's systemd user unit dms.service (`dms run --session`,
# Type=notify, Restart=on-failure), WantedBy graphical-session.target, which
# nebula's uwsm session reaches. Apps it launches get their own systemd-run
# scopes, so restarting the shell does not take them down.
#
# Hyprland wiring is in the stow-managed Lua (home/hyprland/.config/hypr/):
# binds call `dms ipc call …` / `dms screenshot`, and hyprland.lua requires
# only the generated dms/colors.lua fragment (border colours). NEVER run
# `dms setup` — it replaces hyprland.lua, a stow symlink into this repo — and
# don't click the Settings pages' "Setup" banners: they append
# require("dms.<fragment>") lines through that symlink, into the repo copy,
# for fragments that would fight nebula's own Lua. Settings live in
# ~/.config/dms/settings.json (~/.config/DankMaterialShell before 2.0) and
# are not tracked yet. See docs/dux-shell.md.
{
  configurations.nixos.nebula.module =
    { lib, ... }:
    {
      programs.dux-shell.enable = true;

      # Dux registers its own polkit agent (themed dialog on the dms:polkit
      # layer). A session takes one agent, so hyprpolkitagent (enabled in
      # configuration.nix) would race it at graphical-session.target. Keep its
      # unit installed but don't start it while Dux is the shell; disabling
      # this module brings it back.
      systemd.user.services.hyprpolkitagent.wantedBy = lib.mkForce [ ];
    };
}
