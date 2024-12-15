{ inputs, pkgs, lib, hostName, ... }:
{
  imports = [
    ./git.nix
    inputs.nix-config.homeProfiles.essentials
    ./zsh
    ./kitty
  ] ++ lib.optionals (builtins.pathExists ../hosts/${hostName}/users/k) [
    ../hosts/${hostName}/users/k/hm.nix
  ];
  # home.packages = with pkgs; [
  #   gnome-terminal
  # ];
  # programs.kitty.enable = false;
  custom.terminal = "alacritty";
  custom.browser = "brave";
  # programs.firefox.enable = true;
  programs.yazi.enable = true;
  programs.alacritty.enable = true;
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
