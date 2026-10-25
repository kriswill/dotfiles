# nixploit ships its NixOS module in the manic-systems/nixploit flake
# (nix/module.nix); re-export it into the Dendritic module set so hosts pick it
# up like any in-tree modules/nixos/* module. The module defaults
# services.nixploit.package to the flake's own package, so no overlay or pkgs
# wiring is needed. Enable per host with `services.nixploit.enable = true;`.
{ inputs, ... }:
{
  flake.modules.nixos.nixploit = inputs.nixploit.nixosModules.default;
}
