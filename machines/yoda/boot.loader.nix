{ ... }:

{
  boot.loader = {
    timeout = 5;

    efi = {
      # allows grub.efiInstallAsRemovable
      canTouchEfiVariables = false;
      efiSysMountPoint = "/boot";
    };
    # 1) pick systemd-boot:
    # systemd-boot.enable = true;
    # 2) pick grub 2:
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      devices = [ "nodev" ];
      useOSProber = true;
      extraEntriesBeforeNixOS = true;
    };
  };
}