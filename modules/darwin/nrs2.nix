# nrs2 — prototype replacement for nrs (nh darwin switch), installed beside it
# for comparison: nom build → dix diff → validate → system profile → the new
# generation's own `darwin-rebuild activate` (what nh runs), output streamed,
# then a state report. `nrs2 --dry` builds and diffs only; `nrs2 --test` runs
# `darwin-rebuild check` (system.checks, no activation); `nrs2 --status`
# shows the generations with no build and no root; `--plan` acts as `--dry`
# (nix-darwin has no dry-activate). No detach-on-Ctrl-C
# here: that rides on systemd-run, which the NixOS twin
# (modules/nixos/nrs2.nix) has and launchd does not. The tool is
# pkgs/nrs2.{nix,sh}. Why: docs/nrs-pipeline.html (§14–15).
{
  flake.modules.darwin.nrs2 =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.nrs2 ];
    };
}
