{
  description = "pam-tid-gate — Touch ID for sudo only while someone can reach this Mac's own readers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Built and tested on Apple Silicon only.
      systems = [
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, config, ... }:
        {
          packages = {
            pam-tid-gate = pkgs.callPackage ./package.nix { };
            default = config.packages.pam-tid-gate;
          };
        };

      flake.darwinModules = rec {
        pam-tid-gate = import ./darwin-module.nix inputs.self;
        default = pam-tid-gate;
      };
    };
}
