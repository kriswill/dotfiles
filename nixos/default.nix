{ config, pkgs, flake-inputs, ... }:
{
  imports = [
    flake-inputs.home-manager.nixosModules.home-manager
    ./nix.nix
    ./programs.nix
    ./fonts.nix
    ./users.nix
  ];

  time.timeZone = "America/Los_Angeles";

  services = {
    gvfs.enable = true;
    openssh.enable = true;
    printing.enable = false;
  };

  # no root user
  #systemd.enableEmergencyMode = false;

  boot.tmp.cleanOnBoot = true;
  security.rtkit.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11";
}
