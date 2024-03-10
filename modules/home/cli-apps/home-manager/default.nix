{ config, lib, ...}:
let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.internal) enabled;

  cfg = config.k.cli-apps.home-manager;
in
{
  options.k.cli-apps.home-manager = {
    enable = mkEnableOption "home-manager";
  };

  config = mkIf cfg.enable {
    programs.home-manager = enabled;
  };
}