# Declares `configurations.nixos.<name>` and realises each into a
# `nixosConfigurations.<name>` flake output (plus a toplevel build check),
# building through snowglobe-lib's `mkNixosHost` so all the
# `snowglobe-lib.profiles.*` / `snowglobe-lib.desktop.*` machinery and the
# hardware wiring are still applied. Adapted from main's `modules/darwin.nix`.
{
  lib,
  config,
  inputs,
  ...
}:
let
  slib = inputs.snowglobe-lib.lib;
in
{
  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          hostname = lib.mkOption { type = lib.types.str; };
          system = lib.mkOption {
            type = lib.types.str;
            default = "x86_64-linux";
          };
          cpu-vendor = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          gpu-vendors = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          firmware = lib.mkOption {
            type = lib.types.str;
            default = "UEFI";
          };
          isVM = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          stateVersion = lib.mkOption { type = lib.types.str; };
          module = lib.mkOption { type = lib.types.deferredModule; };
        };
      }
    );
    default = { };
    description = "NixOS configurations, keyed by hostname.";
  };

  config.flake.nixosConfigurations = lib.mapAttrs (
    _name: cfg:
    slib.mkNixosHost {
      inherit (cfg)
        hostname
        system
        cpu-vendor
        gpu-vendors
        firmware
        isVM
        stateVersion
        ;
      # mkNixosHost does not inject these; our host modules expect `inputs`.
      specialArgs = { inherit inputs; };
      modules = [ cfg.module ];
    }
  ) config.configurations.nixos;

  config.flake.checks = lib.mkMerge (
    lib.mapAttrsToList (name: cfg: {
      ${cfg.config.nixpkgs.hostPlatform.system}."configurations:nixos:${name}" =
        cfg.config.system.build.toplevel;
    }) config.flake.nixosConfigurations
  );
}
