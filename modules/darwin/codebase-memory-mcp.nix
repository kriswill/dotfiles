# codebase-memory-mcp ships its nix-darwin module with its sub-flake
# (./flakes/codebase-memory-mcp/darwin-module.nix); re-export it into the
# Dendritic module set so hosts pick it up like any in-tree modules/darwin/*
# module. The module defaults kriswill.codebase-memory.package to the sub-flake's
# own package, so no overlay or pkgs wiring is needed. Enable per host with
# `kriswill.codebase-memory.enable = true;`.
{ inputs, ... }:
{
  flake.modules.darwin.codebase-memory-mcp =
    inputs.codebase-memory-mcp.darwinModules.codebase-memory-mcp;
}
