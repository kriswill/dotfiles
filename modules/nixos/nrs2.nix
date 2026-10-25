# nrs2 — prototype replacement for nrs (nh os switch), installed beside it for
# comparison: nom build → dix diff → validate → switch-to-configuration test as
# a transient systemd unit (output streamed; Ctrl-C or a lost terminal
# detaches instead of killing it) → system profile → boot entry, then a state
# report. `nrs2 --dry` builds and diffs only; `nrs2 --test` skips the profile
# and the boot entry. The tool is pkgs/nrs2.{nix,sh}, shared with the darwin
# twin (modules/darwin/nrs2.nix). Why: docs/nrs-pipeline.html (§14–15).
{
  flake.modules.nixos.nrs2 =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.nrs2 ];
    };
}
