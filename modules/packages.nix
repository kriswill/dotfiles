# Custom package outputs (also surfaced into nix-darwin via ./overlays.nix).
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        kitten = pkgs.callPackage ../pkgs/kitten.nix { };
        iv = pkgs.callPackage ../pkgs/iv.nix { };
        ccglass = pkgs.callPackage ../pkgs/ccglass/package.nix { };
      };
    };

  # ccglass also builds on Linux (pure-JS deps, `bun build --compile` → ELF). The
  # repo's `systems` list is aarch64-darwin only, so expose just the extra ccglass
  # outputs directly rather than widening every perSystem output onto Linux.
  flake.packages = builtins.listToAttrs (
    map
      (system: {
        name = system;
        value.ccglass = inputs.nixpkgs.legacyPackages.${system}.callPackage ../pkgs/ccglass/package.nix { };
      })
      [
        "aarch64-linux"
        "x86_64-linux"
      ]
  );
}
