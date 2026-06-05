{
  description = "ccglass — local logging reverse-proxy + web dashboard for coding agents, built as a standalone binary";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      perSystem =
        { pkgs, config, ... }:
        {
          packages = {
            ccglass = pkgs.callPackage ./package.nix { };
            default = config.packages.ccglass;
          };
        };
    };
}
