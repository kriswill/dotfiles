# iv — terminal-graphics image viewer. See pkgs/iv.nix.
_final: prev: {
  iv = prev.callPackage ../pkgs/iv.nix { };
}
