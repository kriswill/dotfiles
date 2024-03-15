{ config, lib, pkgs, modulesPath, inputs, ... }:
let
  inherit (inputs) nixos-hardware;
in
{
  imports = with nixos-hardware.nixosModules; [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  ##
  # Desktop VM config
  ##
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    initrd = {
      kernelModules = [ "kvm-intel" ];
      availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
    };

    extraModulePackages = [ ];
  };

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/64dc6c06-d02f-46a9-986e-4f89b75a8657";
      fsType = "ext4";
    };

  swapDevices = [ ];
}

