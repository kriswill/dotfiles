_: {
  flake.modules.nixos.herdr =
    # herdr — agent multiplexer that lives in your terminal. Pinned to the
    # upstream flake's tag (see the herdr input in flake.nix) instead of
    # nixpkgs' 0.7.5, for in-pane image rendering (docs/fastfetch.md).
    # pkgs.herdr is the flake input's package plus our tab-bar token patch
    # (overlays/herdr-tab-bar-token.patch, wired in modules/overlays.nix).
    # Darwin twin: modules/darwin/herdr.nix.
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
