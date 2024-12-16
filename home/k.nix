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
  # home.packages = with pkgs; [
  #   gnome-terminal
  # ];
  # programs.kitty.enable = false;
  custom.terminal = "alacritty";
  custom.browser = "brave";
  programs = {
    yazi.enable = true;
    alacritty.enable = true;
    fzf.enable = true;
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
