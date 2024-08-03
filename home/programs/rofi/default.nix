{ config, pkgs, ... }:

let
  ln = config.lib.file.mkOutOfStoreSymlink;
  src = "${config.home.homeDirectory}/src/dotfiles";
in {
  home.packages = [
    # rofi 
    pkgs.unstable.rofi-wayland
  ];
  # make a symlink for rofi -- allow for theme selector to work...
  xdg.configFile."rofi".source =
    ln "/home/k/src/dotfiles/home/programs/rofi/config";
}
