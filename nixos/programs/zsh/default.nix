{ pkgs, ... }:

let inherit (pkgs.lib) getExe;
in {
  environment = {
    shells = [ pkgs.zsh ];
    pathsToLink = [ "/share/zsh" ];
  };
  programs.zsh = {
    enable = true;
    enableBashCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting = {
      enable = true;
      highlighters = [ "main" "brackets" ];
    };
    shellAliases = import ./aliases.nix { inherit pkgs; };
    interactiveShellInit = ''
      eval "$(${getExe pkgs.zoxide} init --cmd j zsh)"
      if [ -n "''${commands[fzf-share]}" ]; then
        source "$(fzf-share)/key-bindings.zsh"
        source "$(fzf-share)/completion.zsh"
      fi
    '';
  };
}
