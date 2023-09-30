#
# Configuration for host "nix" running on a Macbook Pro M1Max using Parallels Version 19.0.0 (54570)
#
{ config, pkgs, nixvim, ... }:

{
  imports = [
    ./vm-aarch64-parallels.nix
    ./audio.nix
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
}
