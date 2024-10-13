{ config, pkgs, ... }:

let
  ln = config.lib.file.mkOutOfStoreSymlink;
  src = "${config.home.homeDirectory}/src/github/kriswill/dotfiles";
in
{
  home.packages = [
    # rofi 
    pkgs.rofi-wayland
  ];
  # make a symlink for rofi -- allow for theme selector to work...
  xdg.configFile."rofi".source = ln "${src}/home/programs/rofi/config";
  # ln "/home/k/src/dotfiles/home/programs/rofi/config";
}
