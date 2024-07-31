{ config, pkgs, lib, ... }:

let
  background = pkgs.wallpapers.yoda-dagoba-2;
  ln = config.lib.file.mkOutOfStoreSymlink;
  i3src = "${config.home.homeDirectory}/src/dotfiles/home/programs/i3";
in {
  # to rotate my left monitor
  imports = [ ./grobi ];

  xsession.windowManager.i3 = {
    enable = true;

    config = {
      bars = lib.mkForce [ ]; # disable i3status

      modifier = "Mod4"; # Windows Key
      floating.modifier = "Mod4";
      terminal = "${lib.getBin pkgs.unstable.kitty}";
      keybindings = import ./keybinds.nix;

      startup = [
        {
          command = "systemctl --user restart polybar";
          always = true;
          notification = false;
        }
        {
          command = "${lib.getBin pkgs.unstable.feh} --bg-scale ${background}";
          always = true;
          notification = false;
        }
      ];
    };
  };

  # allows me to automatically configure monitors when logging into i3
  # xdg.configFile."autorandr".source = ln "${i3src}/autorandr";

  # so we can set wallpapers without rebuilding
  home.packages = with pkgs.unstable; [ feh xclip grobi ];

  services = {
    polybar = {
      enable = true;
      script = builtins.readFile ./polybar/launch.sh;
      extraConfig = builtins.readFile ./polybar/polybar.ini;
    };
    # autorandr.enable = true;
  };
}
