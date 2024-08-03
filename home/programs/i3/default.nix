{ config, pkgs, lib, ... }:

let
  background = pkgs.wallpapers.yoda-dagoba-2;
  ln = config.lib.file.mkOutOfStoreSymlink;
  i3src = "${config.home.homeDirectory}/src/dotfiles/home/programs/i3";
  xrandr_script = pkgs.writeScript "yoda-xrandr" ''
    xrandr --output DP-0 --rotate left --mode 3440x1440 --rate 59.97 --pos 0x0 --output DP-2 --primary --mode 3440x1440 --rate 59.97 --pos 1440x1250
  '';
  polybar_script = pkgs.writeScript "polybar_script" /*sh*/''
    killall polybar
    sleep 0.1
    if type "xrandr"; then
      for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
        MONITOR=$m ${lib.getExe pkgs.unstable.polybar} --reload toph -c ~/.config/polybar/polybar.ini &
      done
    else
      ${lib.getExe pkgs.unstable.polybar} --reload toph -c ~/.config/polybar/polybar.ini &
    fi
  '';
in
{
  # so we can set wallpapers without rebuilding
  home.packages = with pkgs.unstable; [ feh xclip grobi pamixer flameshot ];
  xdg.configFile."polybar/polybar.ini".source = ln "${i3src}/polybar/polybar.ini";
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
      defaultWorkspace = "workspace number 1";

      startup = [
        {
          command = "${xrandr_script}";
          always = true;
          notification = false;
        }
        {
          command = "${lib.getExe pkgs.unstable.feh} --bg-scale ${background}";
          always = true;
          notification = false;
        }
        {
          command = "${polybar_script}";
          always = true;
          notification = false;
        }
      ];
    };
  };
}
