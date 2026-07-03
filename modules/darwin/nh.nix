# nh (Nix Helper) — nix-darwin has no programs.nh module; install it plus the
# rebuild helpers. The helpers are real executables (writeShellScriptBin), not
# shell aliases, so they work in non-interactive shells (agent harnesses,
# scripts) and in every shell (zsh, fish, oksh) alike:
#
#   nrs — build + activate            (nh darwin switch; sudo at activation)
#   nrb — build only, no root needed  (nh darwin build)
#   nrt — build + run system.checks without activating (darwin-rebuild check;
#         the old `nh darwin test` / `darwin-rebuild test` subcommands no
#         longer exist upstream)
#
# NH_NO_CHECKS=1 skips nh's pre-flight checks (the flake's own checks rebuild
# all three hosts — too slow for an inner loop). Extra args pass through, e.g.
# `nrs -v`, `nrb --dry`. darwin-rebuild is invoked by bare name: it ships in
# the system profile, not nixpkgs.
{
  flake.modules.darwin.nh =
    { lib, pkgs, ... }:
    let
      nh = lib.getExe pkgs.nh;
      flakeDir = "$HOME/src/dotfiles";
      nrs = pkgs.writeShellScriptBin "nrs" ''
        exec env NH_NO_CHECKS=1 ${nh} darwin switch "${flakeDir}" "$@"
      '';
      nrb = pkgs.writeShellScriptBin "nrb" ''
        exec env NH_NO_CHECKS=1 ${nh} darwin build "${flakeDir}" "$@"
      '';
      nrt = pkgs.writeShellScriptBin "nrt" ''
        exec darwin-rebuild check --flake "${flakeDir}" "$@"
      '';
    in
    {
      environment.systemPackages = [
        pkgs.nh
        nrs
        nrb
        nrt
      ];
    };
}
