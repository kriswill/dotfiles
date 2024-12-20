{ pkgs, ... }:
{
  imports = [
    ./keybinds.nix
    ./virt-manager.nix
    ./extensions.nix
  ];
  home.packages = with pkgs; [ dconf-editor ];
}
