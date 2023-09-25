{ pkgs, environment, username, ... }:

{
  # List packages installed in system profile. To search, run:
  environment = {
    systemPackages = with pkgs; [
      bat # A cat clone with wings.
      eza # A better ls
      fzf # A command-line fuzzy finder
      git # the stupid content tracker
      hstr # Bash and Zsh shell history suggest box
      htop # interactive process viewer
      neofetch # displays system info
      nix-info # display Nix system information
      ripgrep # a better grep
      sysz # systemd browsing tool
      wget # a network utility to retrieve files from the Web
      nvtop # an htop like monitoring tool for NVIDIA GPUs
      inxi # system information script
      usbutils # USB Device Utilities
      lshw # list hardware
      pciutils # PCI bus related utilities
    ];
    shells = with pkgs; [ zsh ];
    sessionVariables = {
      # Needed to run Electron apps under Wayland
      # see: https://github.com/NixOS/nixpkgs/pull/147557
      NIXOS_OZONE_WL = "1";
    };
    # fix for many rust based guis on wayland/gnome/nixos
    # https://github.com/alacritty/alacritty/issues/4780#issuecomment-890408502
    variables.XCURSOR_THEME = "Adwaita";

    gnome.excludePackages = (with pkgs; [
      gnome-photos
      gnome-tour
    ]) ++ (with pkgs.gnome; [
      cheese
      gnome-music
      gedit
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
        highlighters = [ "main" "brackets" ];
      };
      shellAliases = {
        ls = "eza";
        ld = "ls -D";
        ll = "ls -lhF";
        la = "ls -lahF";
        l = "la";
        t = "ls -T -I '.git'";
        cat = "bat";
      };
    };
  };
}
