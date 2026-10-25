# nh (Nix Helper) — nix-darwin has no programs.nh module; install it plus the
# rebuild helpers. The helpers are real executables (writeShellScriptBin), not
# shell aliases, so they work in non-interactive shells (agent harnesses,
# scripts) and in every shell (zsh, fish, oksh) alike:
#
#   nrs — build + activate            (nh darwin switch; sudo at activation)
#   nrb — build only, no root needed  (nh darwin build)
#
# nrt (build + system.checks, no activation) moved to modules/darwin/nrs2.nix
# as `nrs2 --test`. Its old form, a bare `darwin-rebuild check`, was refused
# without root, and under sudo it performs a full activation.
#
# NH_NO_CHECKS=1 skips nh's two startup probes of the system Nix: a version
# check that only warns (minimum 2.31.2) and the nix-command/flakes feature
# check. Both always pass on these Macs (Determinate Nix), so this saves two
# `nix` subprocesses and skips no real safety net (nh never runs the flake's
# own checks). Extra args pass through, e.g.
# `nrs -v`, `nrb --dry`.
{
  flake.modules.darwin.nh =
    { lib, pkgs, ... }:
    let
      nh = lib.getExe pkgs.nh;
      flakeDir = "$HOME/src/dotfiles";
      mkNhHelper =
        name: subcommand:
        pkgs.writeShellScriptBin name ''
          exec env NH_NO_CHECKS=1 ${nh} darwin ${subcommand} "${flakeDir}" "$@"
        '';
    in
    {
      environment.systemPackages = [
        pkgs.nh
        (mkNhHelper "nrs" "switch")
        (mkNhHelper "nrb" "build")
      ];
    };
}
