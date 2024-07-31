{ pkgs }:
let
  ln = config.lib.file.mkOutOfStoreSymlink;
  src = "${config.home.homeDirectory}/src/dotfiles";
in
  with pkgs.unstable; {
    home.packages = [ 
      rofi 
      rofi-wayland 
    ];
    # make a symlink for rofi -- allow for theme selector to work...
    xdg.configFile.rofi.source = ln "${src}/home/programs/rofi/config";
  }
