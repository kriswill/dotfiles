{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.kriswill.glow;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  options.kriswill.glow = {
    enable = mkEnableOption "glow";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [ glow ];
    home.sessionVariables.GLAMOUR_STYLE = "dark";

    xdg.configFile."glow/glow.yml".source = ./glow.yml;
  };
}
