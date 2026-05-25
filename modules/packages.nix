# Custom package outputs (also surfaced into nix-darwin via ./overlays.nix).
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        kitten = pkgs.callPackage ../pkgs/kitten.nix { };
        iv = pkgs.callPackage ../pkgs/iv.nix { };
      };
    };
}
