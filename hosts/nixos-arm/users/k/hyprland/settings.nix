{ config, ... }:

let
  # ln = config.lib.file.mkOutOfStoreSymlink;
  # conf = "/etc/nixos/hosts/yoda/users/k/hyprland/config";
in
{
  wayland.windowManager.hyprland.settings = {
    # source = [
    #   "./monitors.conf"
    # ];
  };

  # xdg = {
  #   configFile = {
  #     "hypr/monitors.conf".source = ln "${conf}/monitors.conf";
  #   };
  # };
}


