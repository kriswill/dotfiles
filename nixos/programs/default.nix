{ pkgs, ... }:
{

  imports = [
    ./vim.nix
    ./zsh.nix
  ];

  environment = {
    systemPackages = with pkgs; [
      bat # cat clone with wings.
      curl # a network utility to retrieve files from the Web
      eza # better ls
      fzf # command-line fuzzy finder
      gh
      git # the stupid content tracker
      home-manager
      hstr # bash and Zsh shell history suggest box
      htop # interactive process viewer
      inxi # system information script
      lshw # list hardware
      lsof # list of open files
      ncdu # disk usage analyzer with an ncurses interface
      dua # disk Usage Analyzer
      fastfetch # displays system info
      nix-info # display Nix system information
      nvd # nix package version diff tool
      pavucontrol
      pciutils # pci bus related utilities
      ranger # file manager
      ripgrep # better grep
      sysz # systemd browsing tool
      usbutils # usb Device Utilities
      wget # network utility to retrieve files from the Web
      zoxide
      gnumake
      kitty
    ];
    extraInit = ''
      # No option to unset in NixOS
      unset SSH_ASKPASS
    '';
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs = {
    nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 5";
    };
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    dconf.enable = true;
    starship.enable = true;
    _1password.enable = true;
    _1password-gui.enable = true;
  };
}
