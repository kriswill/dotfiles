{
  pkgs,
  inputs,
  config,
  lib,
  ...
}: {

  # imports = [
  #   inputs.hyprland.nixosModules.default
  # ];

  config = lib.mkIf config.hyprland.enable {
    nix.settings = {
      substituters = ["https://hyprland.cachix.org"];
      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };

    services.displayManager = {
    #   defaultSession = "hyprland";
    #   sddm.enable = true;
      sddm.wayland.enable = true;
    };

    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = "1";
      NIXOS_OZONE_WL = "1";
    };

    hardware = {
      opengl.enable = true;
      opengl.driSupport = true;
      opengl.driSupport32Bit = true;
      nvidia.modesetting.enable = true;
    };


    environment.systemPackages = with pkgs; [
      dunst # notification deamon for hyprland
      libnotify # needed for dunst to work
      waybar # bar for hyprland
      swww # wallpaper
      rofi-wayland
    ];


    # xdg.portal = {
    #   enable = true;
    #   extraPortals = with pkgs; [
    #     xdg-desktop-portal-gtk
    #   ];
    # };
/*
    security = {
      polkit.enable = true;
      #pam.services.ags = {};
    };

    environment.systemPackages = with pkgs; with gnome; [
      morewaita-icon-theme
      adwaita-icon-theme
      qogir-icon-theme
      loupe
      nautilus
      baobab
      gnome-text-editor
      gnome-calendar
      gnome-boxes
      gnome-system-monitor
      gnome-control-center
      gnome-weather
      gnome-calculator
      gnome-clocks
      gnome-software # for flatpak
      wl-gammactl
      wl-clipboard
      wayshot
      pavucontrol
      brightnessctl
      swww
    ];

    systemd = {
      user.services.polkit-gnome-authentication-agent-1 = {
        description = "polkit-gnome-authentication-agent-1";
        wantedBy = ["graphical-session.target"];
        wants = ["graphical-session.target"];
        after = ["graphical-session.target"];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
        };
      };
    };

    services = {
      gvfs.enable = true;
      devmon.enable = true;
      udisks2.enable = true;
      accounts-daemon.enable = true;
      gnome = {
        evolution-data-server.enable = true;
        glib-networking.enable = true;
        gnome-keyring.enable = true;
        gnome-online-accounts.enable = true;
      };
    };

    # services.greetd = {
    #   enable = true;
    #   settings.default_session.command = pkgs.writeShellScript "greeter" ''
    #     export XKB_DEFAULT_LAYOUT=${config.services.xserver.xkb.layout}
    #     export XCURSOR_THEME=Qogir
    #     ${asztal}/bin/greeter
    #   '';
    # };

    # systemd.tmpfiles.rules = [
    #   "d '/var/cache/greeter' - greeter greeter - -"
    # ];

    # system.activationScripts.wallpaper = let
    #   wp = pkgs.writeShellScript "wp" ''
    #     CACHE="/var/cache/greeter"
    #     OPTS="$CACHE/options.json"
    #     HOME="/home/$(find /home -maxdepth 1 -printf '%f\n' | tail -n 1)"

    #     mkdir -p "$CACHE"
    #     chown greeter:greeter $CACHE

    #     if [[ -f "$HOME/.cache/ags/options.json" ]]; then
    #       cp $HOME/.cache/ags/options.json $OPTS
    #       chown greeter:greeter $OPTS
    #     fi

    #     if [[ -f "$HOME/.config/background" ]]; then
    #       cp "$HOME/.config/background" $CACHE/background
    #       chown greeter:greeter "$CACHE/background"
    #     fi
    #   '';
    # in
    #   builtins.readFile wp;
  */
  };

}