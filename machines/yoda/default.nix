{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  networking.hostName = "yoda";

  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./virtualization.nix
    ./nvidia.nix
    ./steam.nix
    # inputs.home-manager.nixosModules.home-manager
  ];

  # home-manager = {
  #   useGlobalPkgs = true;
  #   useUserPackages = true;
  #   backupFileExtension = "home-manager-backup";
  #   # if not using home-manager switch separately
  #   # users.k = import ./home-manager.nix { inherit pkgs; };
  #   extraSpecialArgs = {
  #     inherit inputs;
  #   };
  # };

  gnome.enable = true;
  hyprland.enable = true;
  services.displayManager.defaultSession = lib.mkForce "gnome";

  # Enable networking
  networking.networkmanager.enable = true;

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
