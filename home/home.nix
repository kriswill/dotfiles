{ pkgs, ... }:

let
  username = "k";
  homeDirectory = "/home/${username}";
  configHome = "${homeDirectory}/.config";
  
  defaultPkgs = with pkgs; [
    exa                # pretty ls
    ncdu               # disk space explorer
    nix-output-monitor # nom: output logger for nix build
    ripgrep            # rg: fast replacement for grep
    tldr               # short manual for common shell commands
    discord
  ];
in
{
  programs.home-manager.enable = true;
  
  imports = builtins.concatMap import [
    ./programs
  ];
  
  xdg = {
    inherit configHome;
    enable = true;
  };
  
  home = {
    inherit username homeDirectory;
    packages = defaultPkgs;
    sessionVariables = {
      EDITOR = "code --wait";
    };
    stateVersion = "23.05";
  };
}
