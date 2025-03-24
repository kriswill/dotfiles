{ pkgs, lib, ... }:

with pkgs; let
  inherit (lib) mkIf;
  inherit (stdenv) isDarwin;
in {
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting = {
      enable = true;
    };

    shellAliases = {
      ls = "${eza}/bin/eza --icons --hyperlink";
      ld = "ls -D";
      ll = "ls -lhF";
      la = "ls -lahF";
      l = "la";
      t = "ls -T -I '.git'";
      cat = "bat";
      ".." = "cd ..;";
      "..." = ".. ..";
      lg = "${lazygit}/bin/lazygit";
      ff = "${fastfetch}/bin/fastfetch";
      gv = "NVIM_APPNAME=gman nvim";
    };

    initExtra = builtins.readFile ./initExtra.sh;
    # initExtra = ''
    #   # Zsh run-help function
    #   autoload -Uz run-help
    #   (( ''${+aliases[run-help]} )) && unalias run-help
    #   alias help=run-help
    # '';
  };
}
