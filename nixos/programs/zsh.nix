{ pkgs, lib, ... }:

let
  inherit (lib) getExe;
in
{
  environment = {
    shells = [ pkgs.zsh ];
    pathsToLink = [ "/share/zsh" ];
  };
  programs.zsh = {
    enable = true;
    enableBashCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting = {
      enable = true;
      highlighters = [
        "main"
        "brackets"
      ];
    };
    shellAliases = import ./shell-aliases.nix { inherit pkgs; };
    interactiveShellInit = ''
      eval "$(${getExe pkgs.zoxide} init --cmd j zsh)"
    '';
  };
}
