{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    syntaxHighlighting = {
      enable = true;
    };

    shellAliases = {
      ls = "eza";
      ld = "ls -D";
      ll = "ls -lhF";
      la = "ls -lahF";
      l = "la";
      t = "ls -T -I '.git'";
      cat = "bat";
      ".." = "cd ..;";
      "..." = ".. ..";
    };
    initExtra = ''
      # Zsh run-help function
      autoload -Uz run-help
      (( ''${+aliases[run-help]} )) && unalias run-help
      alias help=run-help
    '';
  };
}