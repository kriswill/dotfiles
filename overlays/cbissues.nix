# cbissues — browse/filter a repo's Codeberg issues (fzf TUI + --plain).
# See pkgs/cbissues.nix.
_final: prev: {
  cbissues = prev.callPackage ../pkgs/cbissues.nix { };
}
