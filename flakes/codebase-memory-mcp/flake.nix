{
  description = "codebase-memory-mcp — MCP server for codebase memory and graph indexing, built from a Makefile";

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
            codebase-memory-mcp = pkgs.callPackage ./package.nix { };
            default = config.packages.codebase-memory-mcp;
            # cbm-daemon (launchd wrapper) + cbm-ctl (control CLI), C, no PATH deps.
            cbm-tools = pkgs.callPackage ./tools/package.nix {
              inherit (config.packages) codebase-memory-mcp;
            };
          };
        };

      # nix-darwin module: a launchd user agent that supervises the daemon, plus
      # the cbm-tools binaries on PATH. Re-exported into the dotfiles Dendritic
      # module set by modules/darwin/codebase-memory-mcp.nix.
      flake.darwinModules = rec {
        codebase-memory-mcp = import ./darwin-module.nix inputs.self;
        default = codebase-memory-mcp;
      };
    };
}
