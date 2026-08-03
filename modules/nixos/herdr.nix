{ inputs, ... }:
{
  flake.modules.nixos.herdr =
    # herdr — agent multiplexer that lives in your terminal. Pinned to the
    # upstream preview flake (see the herdr input in flake.nix) instead of
    # nixpkgs' stable 0.7.5, for in-pane image rendering (docs/fastfetch.md).
    # Darwin twin (still on nixpkgs stable): the herdr entry in
    # modules/darwin/user-packages.nix.
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.herdr
        # vim-aware ctrl+hjkl pane navigation, bound in herdr's config.toml
        # (stow package `herdr`) — see pkgs/herdr-nav.sh.
        pkgs.herdr-nav
      ];
    };
}
