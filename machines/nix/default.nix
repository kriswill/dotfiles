#
# Configuration for host "nix" running on a Macbook Pro M1Max using Parallels Version 19.0.0 (54570)
#
{ config, pkgs, outputs, ... }:

{
  imports = [
    ./vm-aarch64-parallels.nix
    ./audio.nix
    ./environment.nix
    ./networking.nix
    ./services.nix
    ./gnome.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Use Systemd EFI boot only (no grub)
  boot.loader = {
    systemd-boot.enable = true;
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
}
