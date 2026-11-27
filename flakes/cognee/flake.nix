{
  description = "Cognee agent memory as a native Apple Silicon package and nix-darwin service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs =
    inputs@{ flake-parts, self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" ];

      perSystem = { config, pkgs, ... }: {
        packages.cognee = pkgs.callPackage ./package.nix {
          inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
        };
        packages.default = config.packages.cognee;
        checks.cognee-imports = pkgs.runCommand "cognee-imports" { } ''
          export HOME="$TMPDIR"
          export SYSTEM_ROOT_DIRECTORY="$TMPDIR/system"
          export DATA_ROOT_DIRECTORY="$TMPDIR/data"
          export TELEMETRY_DISABLED=1
          export COGNEE_LOG_FILE=false
          ${config.packages.cognee}/bin/python -c 'import asyncpg, fastembed, gliner2, ladybug, psycopg2, torch; from cognee.api.client import app'
          touch "$out"
        '';
      };

      flake.darwinModules = {
        cognee = import ./darwin-module.nix self;
        default = self.darwinModules.cognee;
      };
    };
}
