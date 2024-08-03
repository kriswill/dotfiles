{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.i3.enable {
    services.xserver = {
      enable = true;
      xkb.layout = "us";
      dpi = 96;
      windowManager.i3 = {
        enable = true;
        package = pkgs.i3;
      };
    };
  };
}
