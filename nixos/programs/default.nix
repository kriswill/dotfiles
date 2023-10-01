{ pkgs, ... }: {

  imports = [ ./vim.nix ./zsh.nix ];

  environment = {
    shells = with pkgs; [ zsh ];

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
      lsof
      neofetch
      pavucontrol
      ranger
      ripgrep
      sysz
      zoxide
      # firefox
    ];
    extraInit = ''
      # No option to unset in NixOS
      unset SSH_ASKPASS
    '';
    pathsToLink = [ "/share/zsh" ];
  };

  programs = {
    dconf.enable = true;
    starship.enable = true;
    _1password.enable = true;
    _1password-gui.enable = true;
  };
}
