# Configuration for host "nix" running on a Macbook Pro M1Max using Parallels Version 19.0.0 (54570)
#
{ pkgs, ... }:

{
  imports = [
    ./vm-aarch64-parallels.nix
    ./audio.nix
    ./networking.nix
    ./services.nix
  ];
  hyprland.enable = true;

  boot.kernelPackages = pkgs.linuxPackages;

  # Use Systemd EFI boot only (no grub)
  boot.loader = {
    systemd-boot.enable = true;
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
}
