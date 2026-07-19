{
  flake.modules.nixos.gtk-dark =
    # Dark GTK apps without breaking libadwaita.
    #
    # On Hyprland, xdg-desktop-portal-gtk broadcasts the appearance settings:
    # `color-scheme = prefer-dark` darkens GTK4/libadwaita apps, and
    # `gtk-theme = adw-gtk3-dark` (also named in home/gtk settings.ini) themes
    # GTK3 apps — this package installs that theme so the name resolves.
    #
    # Do NOT set the GTK_THEME session variable here: libadwaita apps respond
    # to it by discarding their own stylesheet (padding, boxed lists, margins),
    # which is what made Gajim's preferences render cramped. It was only ever
    # needed under niri, where no portal ran to broadcast the color-scheme.
    #
    # The portal reads color-scheme from dconf, which has no default without
    # this. Without it, libadwaita apps (e.g. Nautilus) fell back to the
    # legacy gtk-application-prefer-dark-theme key — which they warn is
    # deprecated — so that key is no longer set in home/gtk's gtk-4.0
    # settings.ini (gtk-3.0 keeps it; GTK3 apps have no portal fallback).
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.adw-gtk3 ];
      programs.dconf = {
        enable = true;
        profiles.user.databases = [
          {
            settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
          }
        ];
      };
    };
}
