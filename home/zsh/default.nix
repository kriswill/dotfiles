{ config
, pkgs
, lib
, ...
}:
{
  programs.zsh = {
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    shellAliases = lib.mkForce (import ./aliases.nix { inherit pkgs config; });

    autocd = true;

    initExtra = # sh
      ''
                ## start zsh.initExtras

                autoload -Uz run-help
                (( ''${+aliases[run-help]} )) && unalias run-help
                alias help=run-help

                setopt interactivecomments # allow comments on the command-line

                export EDITOR=nvim
                export PATH=$(realpath ~/bin):$PATH
        				export MANPAGER='nvim +Man!'

                ### end zsh.initExtras
      '';
  };
}
