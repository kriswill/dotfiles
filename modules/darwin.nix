# Declares `configurations.darwin.<name>` and realises each into a
# `darwinConfigurations.<name>` flake output (plus a toplevel build check).
# Adapted from the mightyiam/dendritic example `nixos.nix`.
{
  lib,
  config,
  inputs,
  ...
}:
let
  # nixpkgs lib extended with the repo's pure helpers (lib/default.nix:
  # the kanagawa palette); injected as the darwin evaluation's `lib` below.
  extendedLib = inputs.nixpkgs.lib.extend (_final: _prev: import ../lib);
in
{
  options.configurations.darwin = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption {
          type = lib.types.deferredModule;
        };
      }
    );
    default = { };
    description = "nix-darwin configurations, keyed by hostname.";
  };

  config.flake.darwinConfigurations = lib.flip lib.mapAttrs config.configurations.darwin (
    _name:
    { module }:
    inputs.darwin.lib.darwinSystem {
      specialArgs = {
        inherit inputs;
        inherit (inputs) self;
        outputs = inputs.self;
        lib = extendedLib;
      };
      modules = [ module ];
    }
  );

  config.flake.checks = lib.mkMerge (
    lib.mapAttrsToList (name: cfg: {
      ${cfg.config.nixpkgs.hostPlatform.system}."configurations:darwin:${name}" =
        cfg.config.system.build.toplevel;
    }) config.flake.darwinConfigurations
  );
}
