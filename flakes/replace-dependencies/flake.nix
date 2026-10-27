{
  description = "nixpkgs' replaceDirectDependencies, patched: rewrites compiler-garbled store paths, survives reordered directory entries, and keeps package identity for vulnerability scanners";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    let
      # replaceDependencies and NixOS's system.replaceDependencies call
      # pkgs.replaceDirectDependencies for every path they rewrite, so
      # replacing it here is all a consumer needs.
      overlay = final: _prev: {
        replaceDirectDependencies = final.callPackage ./replace-direct-dependencies.nix { };
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      # nixpkgs 26.11 dropped x86_64-darwin.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      flake = {
        overlays.default = overlay;
        nixosModules.default = {
          nixpkgs.overlays = [ overlay ];
        };
      };

      perSystem =
        { pkgs, ... }:
        {
          checks = import ./checks.nix {
            inherit pkgs;
            replaceDirectDependencies = pkgs.callPackage ./replace-direct-dependencies.nix { };
          };
        };
    };
}
