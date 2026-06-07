# create custom derivations using pkgs.callPackage
{ pkgs, ... }:
{
  # my-package = pkgs.callPackage ./my-package.nix { };
  helium = pkgs.callPackage ./helium.nix { };
  dots-adopt = pkgs.callPackage ./dots-adopt.nix { };
}
