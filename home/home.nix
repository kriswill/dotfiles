{ pkgs, username, ... }:

let
  homeDirectory = "/home/${username}";
  configHome = "${homeDirectory}/.config";

  defaultPkgs = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" "SourceCodePro" ]; })
    eza                # pretty ls
    ncdu               # disk space explorer
    nix-output-monitor # nom: output logger for nix build
    ripgrep            # fast replacement for grep
    tldr               # short manual for common shell commands
    dconf2nix          # convert dconf settings to nix
    discord
    firefox
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

  # Needed for Nerd Fonts to be found
  fonts.fontconfig.enable = true;

  home = {
    inherit username homeDirectory;
    packages = defaultPkgs;
    sessionVariables = {
      EDITOR = "code --wait";
    };
    stateVersion = "23.05";
  };
}
