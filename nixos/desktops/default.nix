{
  inputs,
  pkgs,
  packages,
  config,
  lib,
  ...
}:

{
  options.gnome = {
    enable = lib.mkEnableOption "Gnome";
  };

  options.hyprland = {
    enable = lib.mkEnableOption "Hyprland";
  };

  options.i3 = {
    enable = lib.mkEnableOption "i3";
  };

  imports = [
    ./gnome
    ./hyprland
    ./i3
    ./sddm.nix
  ];

#   config.services.displayManager.defaultSession = lib.mkDefault "gnome";
}
