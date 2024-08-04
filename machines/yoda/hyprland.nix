{ inputs, pkgs, ... }:

{
  wayland.windowManager = {
    hyprland = {
      enable = true;
      #      extraConfig = builtins.readFile ./hyprland.conf;
    };
  };
  environment.systemPackages = [ inputs.swww.packages.${pkgs.system}.swww ];
}
