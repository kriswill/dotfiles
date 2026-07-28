# herdr-nav — vim-aware pane navigation for herdr (ctrl+h/j/k/l).
# See pkgs/herdr-nav.nix.
_final: prev: {
  herdr-nav = prev.callPackage ../pkgs/herdr-nav.nix { };
}
