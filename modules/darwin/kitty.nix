# Kris' kitty (system-level port of the old home-manager module).
#
# nix-darwin has no programs.kitty, so the config — kitty.conf and the
# kanagawabones theme.conf it `include`s — lives in the stow tree
# (home/kitty/.config/kitty/) and is symlinked into ~ by dotfiles-stow.nix
# (live-editable, no rebuild needed). This module installs the binary. No
# /nix/store paths appear in the config, so nothing needs to be linked during
# activation.
{
  flake.modules.darwin.kitty =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.kitty ];
    };
}
