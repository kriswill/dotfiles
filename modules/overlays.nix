# Nixpkgs overlays, exposed as flake outputs and consumed by the host modules
# via `nixpkgs.overlays = builtins.attrValues config.flake.overlays`.
{ ... }:
{
  flake.overlays = {
    kitten = import ../overlays/kitten.nix;
    direnv = import ../overlays/direnv.nix;
  };
}
