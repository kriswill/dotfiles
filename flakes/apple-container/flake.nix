{
  description = "apple-container — Apple's native macOS container CLI, repackaged from the signed .pkg release";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Apple's container runtime is Apple-Silicon-only.
      systems = [ "aarch64-darwin" ];

      perSystem =
        { pkgs, config, ... }:
        {
          packages = {
            apple-container = pkgs.callPackage ./package.nix { };
            default = config.packages.apple-container;
          };
        };

      flake.darwinModules = rec {
        apple-container = import ./darwin-module.nix inputs.self;
        default = apple-container;
      };
    };
}
