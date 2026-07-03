# pass-xdg — drop-in `pass` that defaults PASSWORD_STORE_DIR to
# $XDG_DATA_HOME/password-store. See pkgs/pass-xdg.nix.
_final: prev: {
  pass-xdg = prev.callPackage ../pkgs/pass-xdg.nix { };
}
