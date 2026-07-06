# codebase-memory-mcp ships its NixOS module in our kriswill/codebase-memory-mcp
# `nix` fork (nix/nixos/module.nix); re-export it into the Dendritic module set so
# hosts pick it up like any in-tree modules/nixos/* module — the twin of
# modules/darwin/codebase-memory-mcp.nix (launchd there, systemd user service
# here). The module defaults services.codebase-memory-mcp.package to the fork's
# own package, so no overlay or pkgs wiring is needed. Enable per host with
# `services.codebase-memory-mcp.enable = true;`.
{ inputs, ... }:
{
  flake.modules.nixos.codebase-memory-mcp =
    inputs.codebase-memory-mcp.nixosModules.codebase-memory-mcp;
}
