let
  etc = { pkgs, ... }: {
    programs = {
      bat.enable = true;

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

      jq.enable = true;
      ssh.enable = true;
      nix-index.enable = true;

      zoxide = {
        enable = true;
        enableZshIntegration = true;
        options = [ ];
      };

    };
  };
in
[
  ./alacritty.nix
  ./git.nix
  ./starship.nix
  ./vscode.nix
  ./zsh.nix
  #./dconf.nix
  #./neofetch.nix
  etc
]
