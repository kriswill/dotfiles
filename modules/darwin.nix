# Declares `configurations.darwin.<name>` and realises each into a
# `darwinConfigurations.<name>` flake output (plus a toplevel build check).
# Adapted from the mightyiam/dendritic example `nixos.nix`.
{
  lib,
  config,
  inputs,
  ...
}:
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
        self = inputs.self;
        outputs = inputs.self;
        # The repo's extended lib (adds mkProgramOption, kanagawa), matching the
        # `lib` that the old `mkDarwin` injected.
        lib = config.kriswill.lib;
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
