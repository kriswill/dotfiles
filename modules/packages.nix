# Custom package outputs (also surfaced into nix-darwin via ./overlays.nix).
{
  perSystem =
    { pkgs, lib, ... }:
    let
      # Yazi Kanagawa flavors as standalone derivations ($out holds flavor.toml
      # + tmtheme.xml). Built here so `scripts/render-yazi-palette.ts` can
      # document the exact files yazi consumes; the home-manager module installs
      # the same derivations from the shared spec. Keyed "kanagawa-<variant>".
      yaziFlavors = import ../pkgs/yazi-kanagawa-flavor/all.nix { inherit lib pkgs; };
    in
    {
      packages = {
        kitten = pkgs.callPackage ../pkgs/kitten.nix { };
        iv = pkgs.callPackage ../pkgs/iv.nix { };
      }
      // lib.mapAttrs' (name: drv: lib.nameValuePair "yazi-${name}" drv) yaziFlavors;
    };
}
