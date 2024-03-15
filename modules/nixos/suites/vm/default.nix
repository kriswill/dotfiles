{ config, lib, options, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.internal) mkBoolOpt enabled;

  cfg = config.k.suites.vm;
in
{
  options.k.suites.vm = {
    enable =
      mkBoolOpt false
        "Whether or not to enable common vm configuration.";
  };

  config = mkIf cfg.enable {
    k = {
      services = {
        spice-vdagentd = enabled;
        #spice-webdav = enabled;
      };
    };
  };
}
