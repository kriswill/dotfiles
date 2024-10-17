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

    initExtra = # sh
      ''
        ### start zsh.initExtras

        autoload -Uz run-help
        (( ''${+aliases[run-help]} )) && unalias run-help
        alias help=run-help

        setopt interactivecomments # allow comments on the command-line
        setopt AUTO_CD # type directory path name to change to that dir

        # let batman command autocomplete like man
        compdef batman=man

        export EDITOR=nvim
        export PATH=$(realpath ~/bin):$PATH
        ### end zsh.initExtras
      '';
  };
}
