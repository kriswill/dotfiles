# Custom package outputs (also surfaced into nix-darwin via ./overlays.nix).
{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = {
        kitten = pkgs.callPackage ../pkgs/kitten.nix { };
        iv = pkgs.callPackage ../pkgs/iv.nix { };
        # ccglass is built by its own flake (./flakes/ccglass); re-export it here.
        ccglass = inputs.ccglass.packages.${system}.ccglass;
      };
    };

  # Re-export the sub-flake's Linux ccglass outputs (the root `systems` list is
  # aarch64-darwin only; the ccglass sub-flake builds all three systems).
  flake.packages = builtins.listToAttrs (
    map
      (system: {
        name = system;
        value.ccglass = inputs.ccglass.packages.${system}.ccglass;
      })
      [
        "aarch64-linux"
        "x86_64-linux"
      ]
  );
}
