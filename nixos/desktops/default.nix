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

  imports = [
    ./gnome
    ./hyprland
    ./sddm.nix
  ];

  config.services.displayManager.defaultSession = lib.mkDefault "gnome";
}
