{ inputs, pkgs, config, lib, ... }:
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
  ];

  config = {
    services.displayManager = {
      defaultSession = "Gnome";
      sddm = {
        enable = true;
        theme = "cattpuccin-mocha";
        wayland.enable = true;
      };
    };

    environment.systemPackages = with pkgs; [(
      catppuccin-sddm.override {
        flavor = "mocha";
        font = "Noto Sans";
        fontSize = "14";
        loginBackground = true;
      }
    )];
  };
}
