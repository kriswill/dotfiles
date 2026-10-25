{
  description = "battlenet — Blizzard's Battle.net launcher on NixOS, in GE-Proton without Steam or umu";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Battle.net is an x86 Windows program; Proton's x86_64 build runs it.
      systems = [ "x86_64-linux" ];

      perSystem =
        { pkgs, config, ... }:
        {
          packages = {
            battlenet = pkgs.callPackage ./package.nix { };
            default = config.packages.battlenet;
          };
        };

      flake.nixosModules = rec {
        battlenet = ./nixos-module.nix;
        default = battlenet;
      };
    };
}
