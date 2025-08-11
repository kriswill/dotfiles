{
  lib,
  config,
  pkgs,
  ...
}:

{
  options.kriswill.zsh.enable = lib.mkEnableOption "kris' zsh";
  config = lib.mkIf config.kriswill.zsh.enable {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;
      syntaxHighlighting = {
        enable = true;
      };
      history = {
        size = 100000;
        save = 10000000;
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
        gv = "NVIM_APPNAME=gman nvim";
      };

      initContent = builtins.readFile ./initExtra.sh;
      # initExtra = ''
      #   # Zsh run-help function
      #   autoload -Uz run-help
      #   (( ''${+aliases[run-help]} )) && unalias run-help
      #   alias help=run-help
      # '';
    };
  };
}
