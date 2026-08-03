{ inputs, ... }:
{
  flake.modules.darwin.herdr =
    # herdr — agent multiplexer that lives in your terminal. Pinned to the
    # upstream flake's v0.8.0 tag (see the herdr input in flake.nix) instead
    # of nixpkgs' 0.7.5, for in-pane image rendering (docs/fastfetch.md).
    # NixOS twin: modules/nixos/herdr.nix.
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
