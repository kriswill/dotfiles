# codebase-memory-mcp ships its nix-darwin module in our kriswill/codebase-memory-mcp
# `nix` fork (nix/darwin/module.nix); re-export it into the Dendritic module set so
# hosts pick it up like any in-tree modules/darwin/* module. The module defaults
# services.codebase-memory-mcp.package to the fork's own package, so no overlay or
# pkgs wiring is needed. Enable per host with `services.codebase-memory-mcp.enable = true;`.
{ inputs, ... }:
{
  flake.modules.darwin.codebase-memory-mcp =
    inputs.codebase-memory-mcp.darwinModules.codebase-memory-mcp;
}
