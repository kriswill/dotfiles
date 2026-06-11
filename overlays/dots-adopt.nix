# Makes the dots-adopt helper (pkgs/dots-adopt.nix) available as pkgs.dots-adopt
# inside the darwin module evaluations (modules/darwin/dotfiles-stow.nix).
final: _prev: {
  dots-adopt = final.callPackage ../pkgs/dots-adopt.nix { };
}
