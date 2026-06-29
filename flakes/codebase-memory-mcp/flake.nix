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
          };
        };
    };
}
