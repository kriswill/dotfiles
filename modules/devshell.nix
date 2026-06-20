# Exposes the repo's dev shell as the flake's default devShell, so
# `nix develop` (and `.#devShells.<system>.default`) drop you into the same
# environment as a bare `nix-shell`. The definition lives in ../shell.nix
# (single source of truth); here we just feed it the overlaid, allowUnfree
# `pkgs` that perSystem provides (see modules/packages.nix).
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = import ../shell.nix { inherit pkgs; };
    };
}
