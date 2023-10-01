{ pkgs, ... }:

{
  environment = {
    shells = with pkgs; [ zsh ];
    pathsToLink = [ "/share/zsh" ];
  };
  programs.zsh = {
    enable = true;
    enableBashCompletion = true;
    autosuggestions.enable = true;
    shellAliases = import ./shell-aliases.nix { inherit pkgs; };
    interactiveShellInit = ''
      eval "$(${pkgs.zoxide}/bin/zoxide init --cmd j zsh)"
    '';
  };
}
