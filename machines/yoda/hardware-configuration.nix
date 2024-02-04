{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/2c0fbb75-0f1f-4e47-893f-649e8cdcfd56";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A9AB-1109";
    fsType = "vfat";
  };

  # Mount the Windows NTFS NVME drives
  #fileSystems."/ntfs/windows" = {
  #  device = "/dev/nvme0n1p4";
  #  fsType = "ntfs-3g";
  #  options = [ "rw" "uid=1000" ];
  #};

  #fileSystems."/ntfs/games" = {
  # device = "/dev/nvme1n1p2";
  # fsType = "ntfs-3g";
  # options = [ "rw" "uid=1000" ];
  #};

  swapDevices = [{ device = "/dev/disk/by-uuid/efa877e0-28bf-42b6-b8f9-4be7018d66df"; }];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno2.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
