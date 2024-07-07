{ pkgs, ... }:

let
  username = "k";
  homeDirectory = "/home/${username}";
  configHome = "${homeDirectory}/.config";

  defaultPkgs = with pkgs; [
    (nerdfonts.override {
      fonts = [
        "SourceCodePro" # `SauceCodePro Nerd Font`
        "JetBrainsMono"
      ];
    })
    eza # pretty ls
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
    vesktop
    gcolor3 # color picker
    xdg-utils # Multiple packages depend on xdg-open at runtime. This includes Discord
    element-desktop-wayland # matrix client
    zoom-us # video conferencing
    lutris # game manager
    unstable.devenv
  ];
in
{
  programs.home-manager = {
    enable = true;
  };

  imports = builtins.concatMap import [ ../../home/${username}/programs ] ++ [ ./hyprland.nix ];

  xdg = {
    inherit configHome;
    enable = true;
  };

  gtk = {
    enable = true;
    # iconTheme.package = pkgs.papirus-icon-theme;
    # iconTheme.name = "ePapirus";
    # theme.package = pkgs.layan-gtk-theme;
    # theme.name = "Layan-light-solid";
    # font.name = "Roboto";
    # font.package = pkgs.noto-fonts;
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
      EDITOR = "code --wait";
    };
    stateVersion = "24.05";
  };
}
