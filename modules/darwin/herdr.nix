_: {
  flake.modules.darwin.herdr =
    # herdr — agent multiplexer that lives in your terminal. Pinned to the
    # upstream flake's tag (see the herdr input in flake.nix) instead of
    # nixpkgs' 0.7.5, for in-pane image rendering (docs/fastfetch.md).
    # pkgs.herdr is the flake input's package — our fork's `custom` branch,
    # which carries the ANSI tab-bar command entries (modules/overlays.nix).
    # NixOS twin: modules/nixos/herdr.nix.
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
