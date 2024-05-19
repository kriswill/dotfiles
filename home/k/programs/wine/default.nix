{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bottles
    winetricks
    #wineWowPackages.stable
    wineWowPackages.staging
    #wineWowPackages.waylandFull
  ];
}