{ pkgs, lib, hostName, ... }:
{
  imports = [
    ./git.nix
  ] ++ lib.optionals (builtins.pathExists ../hosts/${hostName}/users/k) [
    ../hosts/${hostName}/users/k/hm.nix
  ];
  # home.packages = with pkgs; [
  #   gnome-terminal
  # ];
  # programs.kitty.enable = false;
  # custom.terminal = "gnome-terminal";
}
