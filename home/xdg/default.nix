{
  config,
  pkgs,
  lib,
  ...
}:

{
  home = {
    packages = with pkgs; [
      xdg-utils # Multiple packages depend on xdg-open at runtime. This includes Discord
    ];

    pointerCursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };
  };

  xdg = {
    #inherit configHome;
    enable = true;
    configFile = {
      "gtk-4.0/gtk.css".enable = lib.mkForce false;
      # "gtk-4.0/assets".source =
      #     "${config.gtk.theme.package}/share/themes/${config.gtk.theme.name}/gtk-4.0/assets";
      #   "gtk-4.0/gtk.css".source =
      #     "${config.gtk.theme.package}/share/themes/${config.gtk.theme.name}/gtk-4.0/gtk.css";
      #   "gtk-4.0/gtk-dark.css".source =
      # "${config.gtk.theme.package}/share/themes/${config.gtk.theme.name}/gtk-4.0/gtk-dark.css";
    };
  };

  dconf = {
    settings = {
      "org/gnome/desktop/interface" = {
        # gtk-theme = "Adwaita-Dark";
        color-scheme = "prefer-dark";
      };
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-button-images = false;
      gtk-menu-images = false;
      gtk-toolbar-style = "GTK_TOOLBAR_ICONS";
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "Adwaita-dark";
    style = {
      name = "Adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };
}
