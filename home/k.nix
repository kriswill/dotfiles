{ inputs, lib, hostName, ... }:
{
  imports = [
    ./git.nix
    inputs.nix-config.homeProfiles.essentials
  ] ++ lib.optionals (builtins.pathExists ../hosts/${hostName}/users/k) [
    ../hosts/${hostName}/users/k/hm.nix
  ];
  # home.packages = with pkgs; [
  #   gnome-terminal
  # ];
  # programs.kitty.enable = false;
  # custom.terminal = "gnome-terminal";
  custom.browser = "brave";
  programs.firefox.enable = true;
  programs.yazi.enable = true;
}
