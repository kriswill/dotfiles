# nebula — AMD CPU, NVIDIA GPU, UEFI desktop.
#
# Registers into the `configurations.nixos` registry (realised by
# `modules/nixos.nix` through snowglobe-lib's `mkNixosHost`). This file carries
# the host metadata and the shared baseline of its `module`; the host-specific
# pieces live as their own first-class dendritic files under `nebula/`, each a
# flake-parts module that merges into `configurations.nixos.nebula.module` (the
# realizer's `deferredModule` option), so there is no import-tree exclusion and
# no hand-maintained imports list. Non-`.nix` files (secrets.yaml, *.pub) sit in
# `nebula/` too — import-tree only picks up `.nix`, so they are ignored by the
# scan and referenced by path.
{ config, ... }:
{
  configurations.nixos.nebula = {
    hostname = "nebula";
    cpu-vendor = "amd";
    gpu-vendors = [ "nvidia" ];
    firmware = "UEFI";
    isVM = false;
    stateVersion = "26.05";

    module = {
      # Pull in every shared feature module. The host-specific `nebula/*.nix`
      # files merge into this same `module` via the deferredModule, so they need
      # no listing here.
      imports = builtins.attrValues config.flake.modules.nixos;

      # Previously applied via the `nixosModules.default` import-tree wrapper;
      # re-applied here so wowup/hyprland resolve through our overlays.
      nixpkgs.overlays = builtins.attrValues config.flake.overlays;

      # mkNixosHost only sets `sops.defaultSopsFile` when given a `configDir`,
      # which we don't pass — so point it at the host secrets explicitly.
      sops.defaultSopsFile = ./nebula/secrets.yaml;
    };
  };
}
