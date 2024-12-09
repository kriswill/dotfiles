{ pkgs, lib, ... }:

with pkgs; {
  imports = [ ./settings.nix ];

  home.packages = [
    wl-clipboard
  ];

  programs.waybar.bottomBar.settings = {
    clock.format = lib.mkForce " {:%I:%M %p  %m.%d.%Y}";
  };
}
