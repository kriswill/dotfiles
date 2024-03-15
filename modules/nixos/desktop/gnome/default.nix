{ config, lib, options, pkgs, ... }:
let
  inherit (lib) types mkIf mapAttrs optional getExe;
  inherit (lib.internal) mkBoolOpt mkOpt mkDefault enabled;

  cfg = config.k.desktop.gnome;
  gdmHome = config.users.users.gdm.home;

  defaultExtensions = with pkgs.gnomeExtensions; [
    appindicator
    aylurs-widgets
    dash-to-dock
    emoji-selector
    gsconnect
    gtile
    just-perfection
    logo-menu
    no-overview
    remove-app-menu
    space-bar
    top-bar-organizer
    wireless-hid
  ];

  default-attrs = mapAttrs (_key: mkDefault);
  nested-default-attrs = mapAttrs (_key: default-attrs);
in
{
  options.k.desktop.gnome = with types; {
    enable =
      mkBoolOpt false "Whether or not to use Gnome as the desktop environment.";
    color-scheme = mkOpt (enum [ "light" "dark" ]) "dark" "The color scheme to use.";
    extensions = mkOpt (listOf package) [ ] "Extra Gnome extensions to install.";
    monitors = mkOpt (nullOr path) null "The monitors.xml file to create.";
    suspend =
      mkBoolOpt true "Whether or not to suspend the machine after inactivity.";
    wallpaper = {
      light = mkOpt (oneOf [ str package ]) pkgs.khanelinix.wallpapers.flatppuccin_macchiato "The light wallpaper to use.";
      dark = mkOpt (oneOf [ str package ]) pkgs.khanelinix.wallpapers.cat-sound "The dark wallpaper to use.";
    };
    wayland = mkBoolOpt true "Whether or not to use Wayland.";
  };

  config = mkIf cfg.enable {
    environment = {
      systemPackages = with pkgs;
        [
          #   gnome.gnome-tweaks
          #   gnome.nautilus-python
          #   wl-clipboard
        ]
        # ++ defaultExtensions
        # ++ cfg.extensions;
      ;
      gnome.excludePackages = with pkgs.gnome; [
        epiphany
        geary
        gnome-font-viewer
        gnome-maps
        gnome-system-monitor
        pkgs.gnome-tour
      ];
    };

    k = {
      desktop.addons = {
        # electron-support = enabled;
        gtk = enabled;
        alacritty = enabled;
        # wallpapers = enabled;
        thunar = enabled;
      };
      system.xkb.enable = true;
    };

    # Open firewall for samba connections to work.
    networking.firewall.extraCommands = "iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns";

    programs.kdeconnect = {
      enable = true;
      package = pkgs.gnomeExtensions.gsconnect;
    };

    # Required for app indicators
    services = {
      udev.packages = with pkgs; [ gnome3.gnome-settings-daemon ];

      xserver = {
        enable = true;

        libinput.enable = true;
        displayManager.gdm = {
          enable = true;
          autoSuspend = cfg.suspend;
          inherit (cfg) wayland;
        };
        desktopManager.gnome.enable = true;
      };
    };
  };
}
