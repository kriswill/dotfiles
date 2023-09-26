{ pkgs, config, ... }:
{
  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;

    # Configure keymap in X11
    layout = "us";
    # xkbVariant = "";

    # Enable the GNOME Desktop Environment.
    displayManager = {
      defaultSession = "gnome";
      gdm.enable = true;
    };
    desktopManager = {
      gnome.enable = true;
      xterm.enable = false;
    };
    excludePackages = [ pkgs.xterm ];
  };
}
