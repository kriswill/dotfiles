{
  pkgs,
  environment,
  username,
  ...
}:

{
  # List packages installed in system profile. To search, run:
  environment = {
    systemPackages = with pkgs; [
      bat # A cat clone with wings.
      fzf # A command-line fuzzy finder
      git # the stupid content tracker
      hstr # Bash and Zsh shell history suggest box
      htop # interactive process viewer
      nix-info # display Nix system information
      ripgrep # a better grep
      sysz # systemd browsing tool
      wget # a network utility to retrieve files from the Web
      nvtopPackages.full # an htop like monitoring tool for NVIDIA GPUs
      inxi # system information script
      usbutils # USB Device Utilities
      lshw # list hardware
      pciutils # PCI bus related utilities
      yq-go # yaml parser like jq
    ];
    shells = with pkgs; [ zsh ];
    # fix for many rust based guis on wayland/gnome/nixos
    # https://github.com/alacritty/alacritty/issues/4780#issuecomment-890408502
    variables.XCURSOR_THEME = "Adwaita";

    gnome.excludePackages =
      (with pkgs; [
        gnome-photos
        gnome-tour
        gedit
      ])
      ++ (with pkgs.gnome; [
        cheese
        gnome-music
        epiphany
        geary
        gnome-characters
        tali
        iagno
        hitori
        atomix
        yelp
        gnome-contacts
        gnome-initial-setup
      ]);
  };

  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      # Certain features, including CLI integration and system authentication support,
      # require enabling PolKit integration on some desktop environments (e.g. Plasma).
      polkitPolicyOwners = [ username ];
    };

    # Set zsh to be the default shell for the system
    zsh = {
      enable = true;
      enableBashCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting = {
        enable = true;
        highlighters = [
          "main"
          "brackets"
        ];
      };
    };
  };
}
