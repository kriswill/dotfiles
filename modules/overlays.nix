# Nixpkgs overlays, exposed as flake outputs and consumed by the host modules
# via `nixpkgs.overlays = builtins.attrValues config.flake.overlays`.
{ inputs, ... }:
{
  flake.overlays = {
    kitten = import ../overlays/kitten.nix;
    direnv = import ../overlays/direnv.nix;
    # ccglass comes from its own flake (./flakes/ccglass), not an in-tree package.
    # Overlays are pure final/prev functions, so we close over `inputs` here rather
    # than importing a separate file. The system is read off prev at eval time.
    ccglass = _final: prev: {
      ccglass = inputs.ccglass.packages.${prev.stdenv.hostPlatform.system}.ccglass;
    };
  };
}
