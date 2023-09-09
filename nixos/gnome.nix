{ pkgs, ... }: {
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.gnome.gnome-browser-connector.enable = true;
  environment.gnome.excludePackages = with pkgs;
    [
      gnome-connections
      gnome-tour
    ]
    ++ (with gnome; [
      baobab    # disk usage
      epiphany  # browser
      geary     # email client
      gnome-calendar
      gnome-characters
      gnome-clocks
      gnome-contacts
      gnome-logs
      gnome-maps
      gnome-music
      gnome-weather
      yelp      # help
    ]);

  # Prevent poorly auto-discovered ghost printers
  systemd.services.cups-browsed.enable = false;

  environment.systemPackages = with pkgs; [
    gnome.gnome-tweaks
    gnome-extension-manager
  ];
}