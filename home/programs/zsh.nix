{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    syntaxHighlighting = {
      enable = true;
    };

    initExtra = ''
      # Zsh run-help function
      autoload -Uz run-help
      (( ''${+aliases[run-help]} )) && unalias run-help
      alias help=run-help
    '';
  };
}
