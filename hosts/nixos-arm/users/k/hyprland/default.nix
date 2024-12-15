{ wallpapers, pkgs, lib, ... }:

with pkgs; {
  imports = [ ./settings.nix ];

  home.packages = [
    wl-clipboard
  ];

  programs.waybar.bottomBar.settings = {
    clock.format = lib.mkForce " {:%I:%M %p  %m.%d.%Y}";
  };

  # services.hyprpaper =
  #   let
  #     dp1 = builtins.fetchurl wallpapers.yoda-dagoba-1;
  #     dp2 = builtins.fetchurl wallpapers.yoda-dagoba-2;
  #     # dp1 = ../../../assets/wallpapers/yoda-dagoba-1.webp;
  #     # dp2 = ../../../assets/wallpapers/yoda-dagoba-2.jpg;
  #   in
  #   {
  #     enable = true;
  #     settings = {
  #       ipc = "on";
  #       splash = false;
  #       preload = [ "${dp1}" "${dp2}" ];
  #       wallpaper = lib.mkForce [
  #         "DP-1, ${dp1}"
  #         "DP-2, ${dp2}"
  #       ];
  #     };
  #   };
}
