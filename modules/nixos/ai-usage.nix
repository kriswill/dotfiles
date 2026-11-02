# ai-usage on NixOS: the collector (pkgs/ai-usage) plus its daemon as a
# systemd user service, so the herdr-app `ai-usage` mod (home/herdr-app) and
# `ai-usage` in a terminal always have a fresh ~/.cache/ai-usage/usage.json.
# Accounts: ~/.config/ai-usage/config.json (the `ai-usage` stow package).
#
# Bound to graphical-session.target, not default.target: the Anthropic Admin
# key comes from 1Password (`op read`), which needs the desktop app, and k's
# user manager lingers from boot (herdr-core), where default.target would start
# the daemon long before any app is unlocked. A cold `op` handshake that fails
# leaves the API card asking for a refresh; the rest keeps working.
#
# PATH reaches /run/wrappers/bin for the setgid, desktop-integrated `op`
# (never pinned; see pkgs/AGENTS.md).
#
# A rebuild doesn't restart a user unit, so new code runs after
# `systemctl --user restart ai-usage` (that re-reads the Admin key, one
# 1Password approval). Config edits need no restart: each pass rereads it.
# Darwin twin: modules/darwin/ai-usage.nix.
{
  flake.modules.nixos.ai-usage =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.ai-usage ];

      systemd.user.services.ai-usage = {
        description = "AI account usage collector (ai-usage daemon)";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        environment.PATH = lib.mkForce "/run/wrappers/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.ai-usage} daemon";
          Restart = "on-failure";
          RestartSec = 30;
        };
      };
    };
}
