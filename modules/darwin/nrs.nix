# nrs — the rebuild helper (pkgs/nrs.{nix,sh}, shared with the NixOS twin
# modules/nixos/nrs.nix). nom build → dix diff → validate → system profile →
# the new generation's own `darwin-rebuild activate`, output streamed, then a
# state report. It replaced nh on 2026-10-24. No detach-on-Ctrl-C here: that
# rides on systemd-run, which the NixOS twin has and launchd does not.
# Manual: docs/nrs-pipeline.html.
#
#   nrs           build + switch
#   nrb           nrs --dry: build and diff only, no root
#   nrt           nrs --test: build, then the new generation's system.checks
#                 with nothing activated (not `darwin-rebuild check`, which
#                 activates on macOS; knowledge/decisions/nrs-darwin-check-mode.md)
#   nrs --status  generations and switch state, no build and no root
#   nrs --plan    acts as --dry (nix-darwin has no dry-activate)
#
# nrb and nrt are real executables (not aliases), so they work in
# non-interactive shells and every shell alike.
{
  flake.modules.darwin.nrs =
    { lib, pkgs, ... }:
    let
      mode = name: flag: pkgs.writeShellScriptBin name ''exec ${lib.getExe pkgs.nrs} ${flag} "$@"'';
    in
    {
      environment.systemPackages = [
        pkgs.nrs
        (mode "nrb" "--dry")
        (mode "nrt" "--test")
      ];
    };
}
