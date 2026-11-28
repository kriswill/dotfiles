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
        packages.cognee-frontend = pkgs.callPackage ./frontend.nix { };
        packages.default = config.packages.cognee;
        checks.cognee-imports = pkgs.runCommand "cognee-imports" { } ''
          export HOME="$TMPDIR"
          export SYSTEM_ROOT_DIRECTORY="$TMPDIR/system"
          export DATA_ROOT_DIRECTORY="$TMPDIR/data"
          export TELEMETRY_DISABLED=1
          export COGNEE_LOG_FILE=false
          ${config.packages.cognee}/bin/python - <<'PY'
          from importlib.util import find_spec
          import asyncpg, fastembed, ladybug, psycopg2
          from cognee.api.client import app
          assert find_spec("transformers") is None, "unexpected Transformers dependency"
          PY
          touch "$out"
        '';
        checks.cognee-admin-users = pkgs.runCommand "cognee-admin-users" { } ''
          export HOME="$TMPDIR"
          export SYSTEM_ROOT_DIRECTORY="$TMPDIR/system"
          export DATA_ROOT_DIRECTORY="$TMPDIR/data"
          export PYTHON_DOTENV_DISABLED=1
          export TELEMETRY_DISABLED=1
          export COGNEE_LOG_FILE=false
          export REQUIRE_AUTHENTICATION=false
          export ENABLE_BACKEND_ACCESS_CONTROL=false
          export HASH_API_KEY=true
          ${config.packages.cognee}/bin/python ${./test-admin-users.py}
          touch "$out"
        '';
      };

      flake.lib.mkHermesPlugin = pythonPackages: pythonPackages.callPackage ./hermes-plugin.nix { };

      flake.darwinModules = {
        cognee = import ./darwin-module.nix self;
        clientTrust = import ./client-trust.nix { isDarwin = true; };
        default = self.darwinModules.cognee;
      };
      flake.nixosModules.clientTrust = import ./client-trust.nix { isDarwin = false; };
    };
}
