# nrs2 — prototype replacement for nrs (nh os switch), installed beside it for
# comparison: nom build → dix diff → validate → switch-to-configuration test as
# a transient systemd unit (output streamed; Ctrl-C or a lost terminal
# detaches instead of killing it) → system profile → boot entry, then a state
# report. `nrs2 --dry` builds and diffs only; `nrs2 --test` skips the profile
# and the boot entry; `nrs2 --plan` previews the switch (dry-activate plus the
# user units it skips) and changes nothing; `nrs2 --status` checks the
# machine's switch state with no build and no root. The tool is
# pkgs/nrs2.{nix,sh}, shared with the darwin
# twin (modules/darwin/nrs2.nix). Why: docs/nrs-pipeline.html (§14–15).
#
# nrt is `nrs2 --test`: build, then activate without the profile or a boot
# entry.
{
  flake.modules.nixos.nrs2 =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.nrs2
        (pkgs.writeShellScriptBin "nrt" ''exec ${lib.getExe pkgs.nrs2} --test "$@"'')
      ];
    };
}
