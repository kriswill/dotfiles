{ pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting = {
      enable = true;
    };

    shellAliases = {
      ls = "${pkgs.eza}/bin/eza --icons --hyperlink";
      ld = "ls -D";
      ll = "ls -lhF";
      la = "ls -lahF";
      l = "la";
      t = "ls -T -I '.git'";
      cat = "bat";
      ".." = "cd ..;";
      "..." = ".. ..";
      lg = "${pkgs.lazygit}/bin/lazygit";
      ff = "${pkgs.fastfetch}/bin/fastfetch";
      drs = lib.mkIf pkgs.stdenvNoCC.isDarwin "darwin-rebuild switch --flake ~/src/dotfiles";
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
