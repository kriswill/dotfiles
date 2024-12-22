{ inputs, vm, pkgs, lib, hostName, ... }:
{
  imports = [
    ./git.nix
    ./zsh
    ./kitty
  ] ++ lib.optionals (builtins.pathExists ../hosts/${hostName}/users/k) [
    ../hosts/${hostName}/users/k/hm.nix
  ] ++ lib.optionals (hostName != "nixos-arm") [
    inputs.nix-config.homeProfiles.essentials
  ];
  custom.browser = "brave";
  programs = {
    yazi.enable = true;
    fzf.enable = true;
    libreoffice.enable = false;
  };
  stylix.targets = {
    kitty.enable = false;
    alacritty.enable = false;
    bat.enable = false;
    yazi.enable = false;
  };
  home.packages = with pkgs.nerd-fonts; [
    sauce-code-pro
  ];
}
