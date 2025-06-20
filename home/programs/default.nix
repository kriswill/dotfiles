{ ... }:

{
  imports = [
    ./alacritty.nix
    ./fastfetch
    ./git.nix
    # ./kitty
    ./neovim
    ./ssh.nix
    ./starship.nix
    ./tmux
    ./zsh
  ];

  programs = {
    bat.enable = true;
    jq.enable = true;
    nix-index.enable = true;
    # obs-studio.enable = true; # not on mac
    lazygit.enable = true;
    rmpc.enable = true;

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

      defaultCommand = "fd --type f";
      defaultOptions = [
        "--height 40%"
        "--prompt ⟫"
      ];

      changeDirWidgetCommand = "fd --type d";
      changeDirWidgetOptions = [
        "--preview 'tree -C {} | head -200'"
      ];
    };

    htop = {
      enable = true;
      settings = {
        sort_direction = true;
        sort_key = "PERCENT_CPU";
        show_program_path = false;
      };
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [
        "--cmd"
        "j"
      ];
    };

    yazi = {
      enable = true;
      shellWrapperName = "y";
      enableZshIntegration = true;
      settings = {
        mgr.ratio = [
          1
          3
          4
        ];
      };
    };
  };
}
