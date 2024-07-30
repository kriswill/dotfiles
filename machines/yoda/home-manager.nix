{ inputs, pkgs, ... }:

let
  username = "k";
  homeDirectory = "/home/${username}";
  configHome = "${homeDirectory}/.config";

  defaultPkgs = with pkgs.unstable; [
    (nerdfonts.override {
      fonts = [
        "SourceCodePro" # `SauceCodePro Nerd Font`
        "JetBrainsMono"
      ];
    })
    bustle # freedesktop database viewer
    has # command existence checker
    ncdu # disk space explorer
    nix-output-monitor # nom: output logger for nix build
    ripgrep # fast replacement for grep
    tldr # short manual for common shell commands
    dconf2nix # convert dconf settings to nix
    # discord # slack for gamers
    (discord.override {
      withOpenASAR = true;
      withVencord = true;
    })
    github-desktop # github for dummies
    vesktop
    gcolor3 # color picker
    xdg-desktop-portal # might need this...
    xdg-utils # Multiple packages depend on xdg-open at runtime. This includes Discord
    element-desktop-wayland # matrix client
    zoom-us # video conferencing
    lutris # game manager
    devenv # development environments
    unzip
    zip
    vlc # video player
    hydrapaper # wallpaper manager for gnome
    efitools # manipulate UEFI secure boot variables
  ];
in
{
  programs.home-manager = {
    enable = true;
  };

  imports = [ 
    ../../home/programs 
    ../../home/scripts 
  ];
  
  dconf = {
    settings = {
      "org/gnome/desktop/interface" = {
        gtk-theme = "Adwaita-dark";
        color-scheme = "prefer-dark";
      };
    };
  };

  xdg = {
    inherit configHome;
    enable = true;
  };

  qt = {
    enable = true;
    platformTheme.name = "Adwaita-dark";
    style = {
      name = "Adwaita-dark";
      package = pkgs.unstable.adwaita-qt;
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.unstable.gnome.gnome-themes-extra;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-button-images = false;
      gtk-menu-images = false;
      gtk-toolbar-style = "GTK_TOOLBAR_ICONS";
    };
  };

  # Needed for Nerd Fonts to be found
  fonts.fontconfig.enable = true;

  home = {
    inherit username homeDirectory;
    packages = defaultPkgs;
    sessionVariables = {
      # Needed to run Electron apps under Wayland
      # see: https://github.com/NixOS/nixpkgs/pull/147557
      NIXOS_OZONE_WL = "1";
      HOME_SESSION_VARIABLES = "1";
    };
    stateVersion = "24.05";
  };
}
