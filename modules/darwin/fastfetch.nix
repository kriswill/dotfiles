# Kris' fastfetch — the config and logo live in the stow tree
# (home/fastfetch/.config/fastfetch/), symlinked into ~ by dotfiles-stow.nix;
# only the package is nix's business.
{
  flake.modules.darwin.fastfetch =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.fastfetch ];
    };
}
