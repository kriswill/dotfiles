# Kris' direnv + nix-direnv (system-level port of the old home-manager
# programs.direnv).
#
# The shell hook (`eval "$(direnv hook zsh)"`) already lives in the stow zshrc
# (home/zsh/.config/zsh/.zshrc), and direnv.toml is stow-managed (home/direnv).
# What's left for nix is: install the binaries, and drop nix-direnv's stdlib
# (`use flake`/`use nix`, which defines the _nix function) into
# ~/.config/direnv/lib so direnv sources it — the way home-manager's
# nix-direnv integration did (it symlinked the same direnvrc as
# lib/hm-nix-direnv.sh). The file name sorts before zz-nom-wrapper.sh so the nom
# wrapper (modules/darwin/direnv-nom.nix) can redefine _nix afterwards.
{
  flake.modules.darwin.direnv =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = builtins.attrValues {
        inherit (pkgs) direnv nix-direnv;
      };

      # Order 1600: after dotfiles-stow (1500). Run as the user so the dir/link
      # aren't root-owned; ln -sfn keeps the store path current across bumps.
      system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
        /usr/bin/sudo -u k --set-home /bin/sh -c '
          mkdir -p /Users/k/.config/direnv/lib
          ln -sfn ${pkgs.nix-direnv}/share/nix-direnv/direnvrc /Users/k/.config/direnv/lib/nix-direnv.sh
        '
      '';
    };
}
