let
  etc = { pkgs, ... }: {
    programs = {
      bat.enable = true;
      jq.enable = true;
      nix-index.enable = true;
      ssh.enable = true;
      obs-studio.enable = true;
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
  };
in
[
  ./alacritty.nix
  ./git.nix
  ./kitty.nix
  ./starship.nix
  ./vscode.nix
  ./zsh.nix
  ./dconf.nix
  ./firefox
  #./neofetch.nix
  etc
]