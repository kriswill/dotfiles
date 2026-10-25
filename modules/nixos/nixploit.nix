# nixploit ships its NixOS module with its sub-flake
# (./flakes/nixploit/nixos-module.nix: upstream manic-systems/nixploit's module
# plus the services.nixploit.report options); re-export it into the Dendritic
# module set so hosts pick it up like any in-tree modules/nixos/* module. The
# module defaults services.nixploit.package to upstream's own build, so no
# overlay or pkgs wiring is needed. Enable per host with
# `services.nixploit.enable = true;`.
{ inputs, ... }:
{
  flake.modules.nixos.nixploit = inputs.nixploit.nixosModules.nixploit;
}
