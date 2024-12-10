{ pkgs, ... }:
{
  programs.zsh = {
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    shellAliases = import ./aliases.nix { inherit pkgs; };

    autocd = true;

    initExtra = # sh
      ''
        ## start zsh.initExtras

        autoload -Uz run-help
        (( ''${+aliases[run-help]} )) && unalias run-help
        alias help=run-help

        setopt interactivecomments # allow comments on the command-line

        # let batman command autocomplete like man
        compdef batman=man

        export EDITOR=nvim
        export PATH=$(realpath ~/bin):$PATH

        ### end zsh.initExtras
      '';
  };
}
