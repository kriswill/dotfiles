{ config, pkgs, lib, inputs, ... }:

{
  networking.hostName = "yoda";

  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./virtualization.nix
    ./nvidia.nix
    ./steam.nix
  ];

  # gnome.enable = true;
  hyprland.enable = true;
  i3.enable = true;

  # Enable networking
  networking.networkmanager.enable = true;
  # overlay network
  services.zerotierone = {
    enable = true;

    joinNetworks = [
      # Test Network 
      "1c33c1ced0b9fe7c"
    ];
  };

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  services.netdata = {
    enable = true;
    config = {
      global = {
        "debug log" = "syslog";
        "access log" = "syslog";
        "error log" = "syslog";
      };
    };
  };

  # Enable sound with pipewire.
  sound.enable = true;
  security.rtkit.enable = true;
  hardware.pulseaudio.enable = lib.mkForce false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  system.stateVersion = "24.05"; # Be Careful!
}
