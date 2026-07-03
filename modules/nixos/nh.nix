# nh (Nix Helper) rebuild helpers — the NixOS twin of modules/darwin/nh.nix
# (previously shell functions in modules/nixos/zsh.nix, now real executables so
# they work in non-interactive shells and every shell alike):
#
#   nrs — build + activate                      (nh os switch)
#   nrb — build only, no root needed            (nh os build)
#   nrt — activate without a bootloader entry   (nh os test)
#
# NH_NO_CHECKS=1 skips nh's pre-flight checks (the flake's own checks rebuild
# every host — too slow for an inner loop). Extra args pass through, e.g.
# `nrs -v`, `nrb --dry`. The flake dir is resolved with readlink -f: nix's
# `--flake <path>` does not follow a path that is itself a symlink, and
# ~/src/dotfiles is a convenience symlink on nebula (/etc/nixos -> ~/src/dotfiles
# -> the real checkout).
{
  flake.modules.nixos.nh =
    { lib, pkgs, ... }:
    let
      nh = lib.getExe pkgs.nh;
      mkNhHelper =
        name: subcommand:
        pkgs.writeShellScriptBin name ''
          flake="$(${pkgs.coreutils}/bin/readlink -f "$HOME/src/dotfiles")"
          exec env NH_NO_CHECKS=1 ${nh} os ${subcommand} "$flake" "$@"
        '';
    in
    {
      environment.systemPackages = [
        pkgs.nh
        (mkNhHelper "nrs" "switch")
        (mkNhHelper "nrb" "build")
        (mkNhHelper "nrt" "test")
      ];
    };
}
