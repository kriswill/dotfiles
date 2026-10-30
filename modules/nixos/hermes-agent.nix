# Hermes Agent ships its NixOS module with its sub-flake
# (./flakes/hermes-agent/nix/nixosModules.nix: upstream's module made
# single-owner, with a wrapped CLI and herdr's integration plugin as
# options); re-export it into the Dendritic module set so hosts pick it up
# like any in-tree modules/nixos/* module. Inert until a host sets
# `services.hermes-agent.enable = true;` (nebula does, in
# modules/hosts/nebula/hermes-agent.nix). The module defaults
# services.hermes-agent.package to the sub-flake's own package (all optional
# integrations), so no overlay or pkgs wiring is needed.
{ inputs, ... }:
{
  flake.modules.nixos.hermes-agent = inputs.hermes-agent.nixosModules.default;
}
