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
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.adw-gtk3 ];
    };
}
