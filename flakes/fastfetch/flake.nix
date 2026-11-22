{
  description = "fastfetch — nixpkgs' fastfetch wrapped with a build-time logo and a kitten shim that makes the kitty-icat logo draw in Herdr panes, plus a NixOS + nix-darwin module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Wherever nixpkgs builds fastfetch and bash runs.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        {
          pkgs,
          config,
          ...
        }:
        {
          packages = {
            # No logo chosen: config.jsonc decides, and the shim is the only
            # addition. A host picks one through the module, or with
            # `.override { logo = "…"; paddingTop = …; }`.
            fastfetch = pkgs.callPackage ./package.nix { kitten-shim = config.packages.kitten-shim; };
            kitten-shim = pkgs.callPackage ./kitten-shim.nix { };
            default = config.packages.fastfetch;
          };

          # The shim against a stand-in kitten: what it passes through, what
          # it adds on a terminal that answers, and that it can't call itself.
          checks.kitten-shim =
            pkgs.runCommand "fastfetch-kitten-shim-test"
              {
                nativeBuildInputs = [
                  pkgs.bash
                ]
                ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.util-linux; # script(1), for a pty
              }
              ''
                bash ${./tests/kitten-shim.sh} ${config.packages.kitten-shim}/bin
                touch $out
              '';
        };

      flake = {
        nixosModules = rec {
          fastfetch = ./module.nix;
          default = fastfetch;
        };
        darwinModules = rec {
          fastfetch = ./module.nix;
          default = fastfetch;
        };
      };
    };
}
