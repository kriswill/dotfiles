{ inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./nix.nix
    ./programs
    ./fonts.nix
    ./users.nix
    ./desktops
  ];

  time.timeZone = "America/Los_Angeles";

  services = {
    gvfs.enable = true;
    printing.enable = false;
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # no root user
  #systemd.enableEmergencyMode = false;

  boot.tmp.cleanOnBoot = true;
  security.rtkit.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11";
}
