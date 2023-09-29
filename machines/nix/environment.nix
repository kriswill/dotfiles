{ config, pkgs, nixvim, ... }:

{
  environment = {
    variables = {
      EDITOR = "code";
    };

    shells = [ pkgs.zsh ];

    systemPackages = with pkgs; [
      alacritty
      bat
      btop
      curl
      eza
      fzf
      gh
      git
      hstr
      htop
      kitty
      ncdu
      neofetch
      nix-output-monitor # nom
      nixVersions.nix_2_17
      ranger
      ripgrep
      sysz
      zoxide

      (vscode-with-extensions.override {
        vscodeExtensions = with vscode-extensions; [
          bbenoist.nix
          ms-python.python
          ms-azuretools.vscode-docker
          ms-vscode-remote.remote-ssh
          redhat.vscode-yaml
        ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "remote-ssh-edit";
            publisher = "ms-vscode-remote";
            version = "0.47.2";
            sha256 = "1hp6gjh4xp2m1xlm1jsdzxw9d8frkiidhph6nvl24d0h8z34w49g";
          }
        ];
      })

      (neovim.override {
        vimAlias = true;
        configure = {
          packages.myPlugins = with pkgs.vimPlugins; {
            start = [
              vim-lastplace
              vim-nix
            ];
            opt = [ ];
          };
          customRC = ''
            set nocompatible
            set backspace=indent,eol,start
          '';
        };
      })
    ];

  };

  programs = {
    zsh = {
      enable = true;
      enableBashCompletion = true;
      autosuggestions.enable = true;
      shellAliases = {
        ls = "eza --icons";
        ld = "l -D";
        ll = "l -lhF";
        la = "l -a";
        t = "l -T -L3";
        l = "ls -lhF --git -I '.git|.DS_'";
        sudo = "sudo "; # allow for using aliases with sudo
        nrs = "nixos-rebuild switch --flake ~/src/nixos-config --upgrade |& nom";
        g = "git";
      };
      interactiveShellInit = ''
        eval "$(zoxide init --cmd j zsh)"
      '';
    };
    starship.enable = true;
    _1password.enable = true;
    _1password-gui.enable = true;
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

}
