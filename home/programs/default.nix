{ pkgs, ... }:

{
  imports = [
    ./alacritty.nix
    # ./brave # not on mac
    # ./dconf.nix
    # ./firefox
    ./git.nix
    ./kitty
    ./starship.nix
    # ./vscode.nix
    ./neovim
    # ./wine
    ./zsh.nix
  ];

  programs = {
    bat.enable = true;
    jq.enable = true;
    nix-index.enable = true;
    ssh.enable = true;
    # obs-studio.enable = true; # not on mac
    lazygit.enable = true;

    hstr = {
      enable = true;
      enableZshIntegration = true;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    htop = {
      enable = true;
      settings = {
        sort_direction = true;
        sort_key = "PERCENT_CPU";
      };
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd" "j" ];
    };
  };
}
