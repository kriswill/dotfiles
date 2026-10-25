# nrs2 — prototype nh-free rebuild helper for NixOS and nix-darwin, installed
# beside nrs. See pkgs/nrs2.nix.
_final: prev: {
  nrs2 = prev.callPackage ../pkgs/nrs2.nix { };
}
