# nrs — the rebuild helper for NixOS and nix-darwin (nrb, nrt ride on it).
# See pkgs/nrs.nix.
_final: prev: {
  nrs = prev.callPackage ../pkgs/nrs.nix { };
}
