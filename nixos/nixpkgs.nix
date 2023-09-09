{ inputs, ... }:
let
  inherit (inputs) self;
in
{
  nixpkgs = {
    config.allowUnfree = true;
    overlays =
      (builtins.attrValues self.overlays)
      ++ [ (final: prev: import ../../pkgs { pkgs = prev; }) ];
  };
}