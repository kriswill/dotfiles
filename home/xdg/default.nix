{ config, pkgs, ... }:

{
  xdg = {
    #inherit configHome;
    enable = true;
    configFile = {
      "gtk-4.0/assets".source =
        "${config.gtk.theme.package}/share/themes/${config.gtk.theme.name}/gtk-4.0/assets";
      "gtk-4.0/gtk.css".source =
        "${config.gtk.theme.package}/share/themes/${config.gtk.theme.name}/gtk-4.0/gtk.css";
      "gtk-4.0/gtk-dark.css".source =
        "${config.gtk.theme.package}/share/themes/${config.gtk.theme.name}/gtk-4.0/gtk-dark.css";
    };
  };

  dconf = {
    settings = {
      "org/gnome/desktop/interface" = {
        gtk-theme = "Adwaita-Dark";
        color-scheme = "prefer-dark";
      };
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-Dark";
      package = pkgs.unstable.gnome-themes-extra;
    };
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
      package = pkgs.unstable.adwaita-qt;
    };
  };
}
