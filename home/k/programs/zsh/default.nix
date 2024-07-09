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

    initExtra = builtins.readFile ./init-extra.sh;
  };
}

