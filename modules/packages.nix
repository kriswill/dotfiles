# Custom package outputs (also surfaced into nix-darwin via ./overlays.nix).
{ inputs, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    {
      packages = {
        kitten = pkgs.callPackage ../pkgs/kitten.nix { };
        iv = pkgs.callPackage ../pkgs/iv.nix { };
        dots-adopt = pkgs.callPackage ../pkgs/dots-adopt.nix { };
        # ccglass is built by its own flake (./flakes/ccglass); re-export it here.
        ccglass = inputs.ccglass.packages.${system}.ccglass;
      }
      # apple-container is built by its own flake (./flakes/apple-container) and is
      # Apple-Silicon-only; guard so adding another system to the root `systems` list
      # doesn't break eval on this line.
      // lib.optionalAttrs (system == "aarch64-darwin") {
        apple-container = inputs.apple-container.packages.${system}.apple-container;
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
