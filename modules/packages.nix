# Custom package outputs (also surfaced into nix-darwin via ./overlays.nix).
{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        kitten = pkgs.callPackage ../pkgs/kitten.nix { };
        iv = pkgs.callPackage ../pkgs/iv.nix { };

        # The Yazi kanagawa flavor as a standalone derivation ($out holds
        # flavor.toml + tmtheme.xml), so `scripts/render-yazi-palette.ts` can
        # document the exact files yazi consumes. lib.kanagawa is injected the
        # same way modules/lib.nix does for the darwin/home-manager evals.
        yazi-kanagawa-flavor = import ../modules/home-manager/yazi/_themes/kanagawa {
          inherit pkgs;
          lib = pkgs.lib // { kanagawa = import ../lib/kanagawa.nix; };
        };
      };
    };
}
