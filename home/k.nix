{ pkgs, ... }:
{
  imports = [ ./git.nix ];
  # home.packages = with pkgs; [
  #   gnome-terminal
  # ];
  # programs.kitty.enable = false;
  # custom.terminal = "gnome-terminal";
}
