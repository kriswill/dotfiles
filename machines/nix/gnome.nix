{ config, pkgs, ... }:

{
  services = {
    # Enable the windowing system.
    xserver = {
      enable = true;

      # Configure keymap
      layout = "us";
      xkbVariant = "";

      displayManager = {
        # Enable automatic login for the user.
        autoLogin.enable = true;
        autoLogin.user = "k";

        # the GNOME Desktop Environment.
        gdm.enable = true;
      };
      desktopManager = {
        gnome.enable = true;
        xterm.enable = false;
      };
      excludePackages = [ pkgs.xterm ];
    };
  };

  # Prevent installation of select Gnome software
  environment.gnome.excludePackages = (with pkgs; [
    gnome-photos
    gnome-tour
    xterm # ancient terminal
  ]) ++ (with pkgs.gnome; [
    cheese # webcam tool
    gnome-music
    gnome-terminal
    gedit # text editor
    epiphany # web browser
    geary # email reader
    evince # document viewer
    gnome-characters
    totem # video player
    tali # poker game
    iagno # go game
    hitori # sudoku game
    atomix # puzzle game
  ]);

}
