{ pkgs, ... }:
with pkgs.unstable;
{

  imports = [ ./settings.nix ];

  wayland.windowManager.hyprland = {
    enable = true;

    # plugins = with inputs.hyprland-plugins.packages.${pkgs.system}; [
    #   hyprbars
    #   hyprexpo
    # ];

    systemd = {
      variables = [ "--all" ];
      extraCommands = [
        "systemctl --user stop graphical-session.target"
        "systemctl --user start hyprland-session.target"
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
      morewaita-icon-theme
      qogir-icon-theme
      loupe
      baobab
      wl-gammactl
      wl-clipboard
      wayshot
      pavucontrol
      brightnessctl
      gnome-text-editor
      nautilus # file manager
      adwaita-icon-theme
      gnome-calendar
      gnome-system-monitor
      gnome-calculator
    ]
    ++ (with gnome; [
      gnome-boxes
      gnome-control-center
      gnome-weather
      gnome-clocks
      gnome-software # for flatpak
    ]);
}
