# direnv + nix-direnv — the NixOS twin of modules/darwin/direnv.nix (nebula
# previously got direnv only transitively; now it's explicit).
#
# The shell hook (`eval "$(direnv hook zsh)"`) already lives in the stow zshrc
# (home/zsh/.config/zsh/.zshrc), and direnv.toml is stow-managed (home/direnv).
# What's left for nix is: install the binaries, and drop nix-direnv's stdlib
# (`use flake`/`use nix`, which defines the _nix function) into
# ~/.config/direnv/lib so direnv sources it. The file name sorts before
# zz-nom-wrapper.sh so the nom wrapper (modules/nixos/direnv-nom.nix) can
# redefine _nix afterwards.
{
  flake.modules.nixos.direnv =
    { pkgs, ... }:
    let
      user = "k";
      home = "/home/k";
    in
    {
      environment.systemPackages = builtins.attrValues {
        inherit (pkgs) direnv nix-direnv;
      };

      # Declarative symlink (tmpfiles, not an activation script — same idiom as
      # modules/nixos/tmux.nix); L+ replaces a stale link so the store path
      # stays current across bumps.
      systemd.tmpfiles.rules = [
        "d ${home}/.config/direnv 0755 ${user} users - -"
        "d ${home}/.config/direnv/lib 0755 ${user} users - -"
        "L+ ${home}/.config/direnv/lib/nix-direnv.sh - - - - ${pkgs.nix-direnv}/share/nix-direnv/direnvrc"
      ];
    };
}
