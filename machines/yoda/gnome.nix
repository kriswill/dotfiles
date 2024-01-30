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

  environment = {

    sessionVariables = {
      # Needed to run Electron apps under Wayland
      # see: https://github.com/NixOS/nixpkgs/pull/147557
      NIXOS_OZONE_WL = "1";
    };
    # fix for many rust based guis on wayland/gnome/nixos
    # https://github.com/alacritty/alacritty/issues/4780#issuecomment-890408502
    variables.XCURSOR_THEME = "Adwaita";
  };

  environment.gnome.excludePackages = (with pkgs; [
    gnome-photos
    gnome-tour
    gedit
  ]) ++ (with pkgs.gnome; [
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
}
