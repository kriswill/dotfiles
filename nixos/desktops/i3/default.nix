{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.i3.enable {
    services.xserver = {
      enable = true;
      xkb.layout = "us";
      windowManager.i3 = {
        enable = true;
        package = pkgs.unstable.i3-gaps;
      };
    };
  };
}
