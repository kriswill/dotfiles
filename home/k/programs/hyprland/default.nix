{ pkgs, ... }:

with pkgs.unstable; {
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    package = waybar;
    settings = {
      mainBar = {
        layer = "top";
        spacing = 8;
        modules-left = [ "hyprland/submap" ];
        modules-center = [ "hyprland/workspaces" ];
        modules-right = [ "tray" "pulsaudio" "clock" ];
        tray.spacing = 10;
        clock = {
          format = "{:%T}";
          format-alt = "{:%F}";
          interval = 1;
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };
        "hyprland/submap" = {
          format = " <b>{}</b>";
          tooltop = false;
        };
        "hyprland/workspaces".persistent-workspaces = {
          "1" = [];
          "2" = [];
          "3" = [];
          "4" = [];
          "5" = [];
          "6" = [];
          "7" = [];
          "8" = [];
          "9" = [];
          "10" = [];
        };
        pulseaudio = {
          format = "{icon}";
          format-bluetooth = "{icon}";
          format-bluetooth-muted = "";
          format-muted = "";
          format-icons.default = [ "" "" "" ];
          on-click = "${pavucontrol}/bin/pavucontrol";
        };
      };

      # style = /*css*/''
      #   * {
      #     font-family: FontAwesome, Roboto, Helvetica, Arial, sans-serif;
      #     font-size: 13px;
      #   }
      #   window#waybar {background-color: #303030; border-radius: 0 0 16px 16px;}
      #   #clock, #mpris, #submap, #workspaces, #privacy-item, #tray, #pulseaudio {
      #     color: #f0f0f0;
      #     background-color: #903cf5;
      #     margin: 4px 0;
      #     border-radius: 16px;
      #     padding: 2px 10px;
      #   }
      #   #clock, #mpris, #battery {color: #290056; background-color: #d57bff;}
      #   #privacy-item {background-color: #9a1818}
      #   #clock {margin-left: 10px; font-weight: bolder;}
      #   #pulseaudio {margin-right: 10px;}
      #   #workspaces {padding: 2px 4px;}
      #   #workspaces button {color: #f0f0f0; border-radius: 16px; padding: 0 1px; margin: 2px;}
      #   #workspaces button.active {background-color: #d57bff;}
      #   #workspaces button.empty {color: #a0a0a0;}
      #   #workspaces button.visible {color: #290056; font-weight: bolder;}
      # '';
    };
  };
}
