{ pkgs, ... }: {
  imports = [
    ./alacritty.nix
    ./brave
    ./dconf
    ./firefox
    ./git.nix
    ./hyprland
    ./kitty.nix
    ./starship.nix
    ./neovim
    ./vscode.nix
    ./waybar
    ./gBar
    ./wine
    ./yazi
    ./zsh
    ./rofi
    ./ssh
    ./i3
  ];

  home.packages = with pkgs.unstable; [
    yq-go # yaml parser
  ];
  programs = {
    bat.enable = true;
    jq.enable = true;
    nix-index.enable = true;
    obs-studio.enable = true;
    lazygit.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    fd = {
      enable = true;
      ignores = [
        ".git/"
        "*.bak"
        ".direnv/"
      ];
    };
    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f";
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
