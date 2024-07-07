{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting = {
      enable = true;
    };

    shellAliases = import ./aliases.nix { inherit pkgs; };

    initExtra = ''
      # Zsh run-help function
      autoload -Uz run-help
      (( ''${+aliases[run-help]} )) && unalias run-help
      alias help=run-help
    '';
  };
}

