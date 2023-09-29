#
# Configuration for host "nix" running on a Macbook Pro M1Max using Parallels 18.2 (53488)
#
{ config, pkgs, nixvim, ... }:

{
  imports = [
    ./vm-aarch64-parallels.nix
    ./locale.nix
    ./audio.nix
    ./fonts.nix
    ./users/root.nix
    ./users/k.nix
    ./environment.nix
    ./networking.nix
    ./services.nix
    ./gnome.nix
  ];

  # Linux Kernel 6.1.28 on May 16, 2023
  boot.kernelPackages = pkgs.linuxPackages_6_1;

  # Use Systemd EFI boot only (no grub)
  boot.loader = {
    systemd-boot.enable = true;
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  # Allow unfree packages
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnsupportedSystem = true;
    };
  };

  # Enable Nix Flakes
  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  system = {
    autoUpgrade = {
      enable = true;
      channel = "https://nixos.org/channels/nixos-unstable";
    };

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    stateVersion = "23.05"; # Did you read the comment?
  };
}
