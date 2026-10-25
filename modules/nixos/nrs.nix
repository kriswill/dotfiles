# nrs — the rebuild helper (pkgs/nrs.{nix,sh}, shared with the darwin twin
# modules/darwin/nrs.nix). nom build → dix diff → validate →
# switch-to-configuration test as a transient systemd unit (output streamed;
# Ctrl-C or a lost terminal detaches instead of killing it) → system profile →
# boot entry, then a state report. It replaced nh on 2026-10-24.
# Manual: docs/nrs-pipeline.html.
#
#   nrs           build + switch
#   nrb           nrs --dry: build and diff only, no root
#   nrt           nrs --test: activate without the profile or a boot entry
#   nrs --plan    preview the switch (dry-activate plus the user units it
#                 skips) and change nothing
#   nrs --status  the machine's switch state, no build and no root
#
# nrb and nrt are real executables (not aliases), so they work in
# non-interactive shells and every shell alike.
{
  flake.modules.nixos.nrs =
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
