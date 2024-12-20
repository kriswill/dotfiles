{ wallpapers, pkgs, lib, ... }:

with pkgs; {
  imports = [ ./settings.nix ];

  home.packages = [
    wl-clipboard
  ];

  programs.waybar.bottomBar.settings = {
    clock.format = lib.mkForce " {:%I:%M %p  %m.%d.%Y}";
  };

  services.swww.enable = false;

  services.hyprpaper =
    let
      dp1 = builtins.fetchurl wallpapers.yoda-dagoba-1;
      dp2 = builtins.fetchurl wallpapers.yoda-dagoba-2;
    in
    {
      enable = lib.mkForce true;
      settings = {
        ipc = "on";
        splash = false;
        preload = [ "${dp1}" "${dp2}" ];
        wallpaper = lib.mkForce [
          "DP-1, ${dp1}"
          "DP-2, ${dp2}"
        ];
      };
    };
}
