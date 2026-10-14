_: {
  flake.modules.nixos.herdr =
    # herdr — agent multiplexer that lives in your terminal. Pinned to the
    # upstream flake's tag (see the herdr input in flake.nix) instead of
    # nixpkgs' 0.7.5, for in-pane image rendering (docs/fastfetch.md).
    # pkgs.herdr is the flake input's package — our fork's `v0.9.5-custom` tag,
    # which carries the ANSI tab-bar command entries and nested-shell agent
    # detection (modules/overlays.nix).
    # Darwin twin: modules/darwin/herdr.nix.
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.herdr
        # vim-aware ctrl+hjkl pane navigation, bound in herdr's config.toml
        # (stow package `herdr`) — see pkgs/herdr-nav.sh.
        pkgs.herdr-nav
        # herdr's Claude integration hook (~/.claude/hooks/herdr-agent-state.sh)
        # reports the session id over the herdr socket with python3, and exits
        # silently without it. Without that report, herdr can't resume Claude
        # sessions after a server restart.
        pkgs.python3
      ];
    };
}
