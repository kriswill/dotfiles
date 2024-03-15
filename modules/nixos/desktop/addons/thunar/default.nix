{ config, lib, options, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.internal) mkBoolOpt;

  cfg = config.k.desktop.addons.thunar;
in
{
  options.k.desktop.addons.thunar = {
    enable = mkBoolOpt false "Whether to enable the xfce file manager.";
  };

  config = mkIf cfg.enable {
    programs.thunar = {
      enable = true;
    };
  };
}
