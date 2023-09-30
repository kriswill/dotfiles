{ pkgs, ... }: {

  environment = {
    shells = [ pkgs.zsh pkgs.bash ];

    systemPackages = with pkgs; [
      bat
      curl
      eza
      fzf
      gh
      git
      home-manager
      hstr
      ncdu
      neofetch
      pavucontrol
      ranger
      ripgrep
      sysz
      zoxide
      # firefox
    ] ++ [
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
    extraInit = ''
      # No option to unset in NixOS
      unset SSH_ASKPASS
    '';
    pathsToLink = [ "/share/zsh" ];
  };

  programs = {
    zsh = {
      enable = true;
      enableBashCompletion = true;
      autosuggestions.enable = true;
      shellAliases = {
        ls = "${pkgs.eza}/bin/eza --icons";
        ld = "l -D";
        ll = "l -lhF";
        la = "l -a";
        t = "l -T -L3";
        l = "ls -lhF --git -I '.git|.DS_'";
        cat = "${pkgs.bat}/bin/bat";
        sudo = "sudo "; # allow for using aliases with sudo
        nrs = "sudo -s nixos-rebuild switch --upgrade";
        g = "${pkgs.git}/bin/git";
      };
      interactiveShellInit = ''
        eval "$(zoxide init --cmd j zsh)"
      '';
    };
    dconf.enable = true;
    starship.enable = true;
    _1password.enable = true;
    _1password-gui.enable = true;
  };
}
