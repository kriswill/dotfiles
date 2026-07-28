{
  flake.modules.nixos.herdr =
    # herdr — agent multiplexer that lives in your terminal (from nixpkgs).
    # Darwin twin: the herdr entry in modules/darwin/user-packages.nix.
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.herdr
        # vim-aware ctrl+hjkl pane navigation, bound in herdr's config.toml
        # (stow package `herdr`) — see pkgs/herdr-nav.sh.
        pkgs.herdr-nav
      ];
    };
}
