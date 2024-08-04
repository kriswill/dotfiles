{ config, pkgs, ... }:
let ln = config.lib.file.mkOutOfStoreSymlink;
in with pkgs.unstable; {

  # live symlink for config files, makes live reload for config faster, for now.
  xdg.configFile."hypr".source = ln
    "${config.home.homeDirectory}/src/dotfiles/home/programs/hyprland/config";

  home.packages = [
    # screenshot tools
    grim
    slurp
    swappy
    hyprpicker # https://github.com/hyprwm/hyprpicker
    dunst # notification deamon for hyprland
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
  ] ++ (with gnome; [
    gnome-boxes
    gnome-control-center
    gnome-weather
    gnome-clocks
    gnome-software # for flatpak
  ]);
}
