{ pkgs, ... }:
with pkgs;
{

  imports = [ ./settings.nix ];

  wayland.windowManager.hyprland = {
    enable = true;

    # plugins = with inputs.hyprland-plugins.packages.${pkgs.system}; [
    #   hyprbars
    #   hyprexpo
    # ];

    systemd = {
      enable = false;
      # variables = [ "--all" ];
      # extraCommands = [
      #   "systemctl --user stop graphical-session.target"
      #   "systemctl --user start hyprland-session.target"
      # ];
    };
  };

  services.hyprpaper =
    let
      dp1 = "${../../../packages/shared/wallpapers/yoda-dagoba-1.webp}";
      dp2 = "${../../../packages/shared/wallpapers/yoda-dagoba-2.jpg}";
    in
    {
      enable = true;
      settings = {
        ipc = "on";
        splash = false;
        preload = [
          dp1
          dp2
        ];
        wallpaper = [
          "DP-1, ${dp1}"
          "DP-2, ${dp2}"
        ];
      };
    };

  home.packages =
    [
      # screenshot tools
      grim
      slurp
      swappy
      hyprpicker # https://github.com/hyprwm/hyprpicker
      dunst # notification deamon
      libnotify # needed for dunst to work
      swww # wallpaper
      rofi-wayland
      baobab
      wl-gammactl
      wl-clipboard
      wayshot
      pavucontrol
      brightnessctl
      nautilus # file manager
      gnome-system-monitor
      gnome-calculator
    ];
}
