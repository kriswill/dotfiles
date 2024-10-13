{
  pkgs,
  config,
  lib,
  packages,
  ...
}:
{
  config = lib.mkIf config.gnome.enable {
    services.xserver = {
      enable = true;
      xkb.layout = "us";
      desktopManager = {
        gnome.enable = true;
        # plasma5.enable = true;
      };
    };

    # stuff for the desktops
    qt = {
      enable = true;
      platformTheme = "gnome";
      style = "adwaita-dark";
    };

    programs.dconf.enable = true;
    # resolve conflict for plasma and gnome
    programs.ssh.askPassword = lib.mkForce "/nix/store/0dsjcbp33ibm4zkbhm99d3fxslnaj28v-seahorse-43.0/libexec/seahorse/ssh-askpass";

    environment.gnome.excludePackages =
      (with pkgs; [
        gnome-photos
        gnome-tour
        gedit
        wl-clipboard-rs
        gnome-contacts
        gnome-initial-setup
      ])
      ++ (with pkgs.gnome; [
        cheese
        gnome-music
        epiphany
        gnome-characters
        tali
        iagno
        hitori
        atomix
        yelp
      ]);

    environment.systemPackages = with pkgs; [
      gnome-tweaks
      gnome-system-monitor
      #gnomeExtensions.custom-vpn-toggler
      gnomeExtensions.dual-monitor-toggle
      evince
      libsForQt5.kalk # calculator
      libsForQt5.kpmcore # library for partition manager
      partition-manager # KDE partition manager
      (packages.tilingshell)
    ];
  };
}
