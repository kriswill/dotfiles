# battlenet ships its NixOS module with its sub-flake
# (./flakes/battlenet/nixos-module.nix: the `battlenet` launcher, GE-Proton run
# directly in an FHS environment); re-export it into the Dendritic module set so
# hosts pick it up like any in-tree modules/nixos/* module. The module builds
# the launcher from the host's own pkgs, so no overlay is needed. Enable per
# host with `programs.battlenet.enable = true;`.
{ inputs, ... }:
{
  flake.modules.nixos.battlenet = inputs.battlenet.nixosModules.battlenet;
}
