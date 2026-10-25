{
  description = "nixploit — Nix vulnerability scanning (manic-systems/nixploit) with an HTML report viewer and dependency analysis";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    # The scanner and its NixOS module. No binary cache upstream, so it builds
    # from source; following nixpkgs keeps it on the consumer's package set.
    upstream = {
      url = "github:manic-systems/nixploit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # NixOS only: the module and the report step read /run/current-system and
      # the system profiles.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        {
          pkgs,
          config,
          inputs',
          ...
        }:
        {
          packages = {
            nixploit = inputs'.upstream.packages.default;
            nixploit-report-graph = pkgs.callPackage ./report-graph.nix { };
            nixploit-report = pkgs.callPackage ./report.nix {
              inherit (config.packages) nixploit-report-graph;
            };
            default = config.packages.nixploit;
          };
        };

      flake.nixosModules = rec {
        nixploit = import ./nixos-module.nix inputs;
        default = nixploit;
      };
    };
}
