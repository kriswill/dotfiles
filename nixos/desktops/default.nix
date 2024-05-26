{ inputs, pkgs, config, lib, ... }:
{
  imports = [
    ./gnome
    # ./hyprland
  ];

  options.gnome = {
    enable = lib.mkEnableOption "Gnome";
  };

  options.hyprland = {
    enable = lib.mkEnableOption "Hyprland";
  };

  config.services.displayManager = {
    defaultSession = "gnome";
    sddm.enable = true;
  };
}
