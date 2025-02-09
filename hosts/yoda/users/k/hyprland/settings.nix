{ config, ... }:

let
  ln = config.lib.file.mkOutOfStoreSymlink;
  conf = "/home/k/src/dotfiles/hosts/yoda/users/k/hyprland/config";
in
{
  wayland.windowManager.hyprland.settings = {
    # monitor = "DP-1, transform, 3"; # 270 degrees
    # source = [
    #   "./monitors.conf"
    # ];
  };

  xdg = {
    configFile = {
      "hypr/monitors.conf".source = ln "${conf}/monitors.conf";
    };
  };
}


