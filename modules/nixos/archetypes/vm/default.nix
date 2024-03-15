{ config, lib, options, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.internal) mkBoolOpt enabled;

  cfg = config.k.archetypes.vm;
in
{
  options.k.archetypes.vm = {
    enable =
      mkBoolOpt false "Whether or not to enable the vm archetype.";
  };

  config = mkIf cfg.enable {
    k = {
      suites = {
        common = enabled;
        desktop = enabled;
        # development = enabled;
        vm = enabled;
      };
    };
  };
}
