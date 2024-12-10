{ config, lib, ... }:
{
  boot = {
    kernelParams = [
      "quiet"
      "noatime"
    ];
    supportedFilesystems = [ "ntfs" ];
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    loader = {
      efi.canTouchEfiVariables = lib.mkForce false;
      timeout = 5;
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        devices = [ "nodev" ];
        gfxmodeEfi = lib.mkForce "3440x1440";
        extraEntries = lib.mkForce ''
          menuentry "Windows" --class windows --class os {
            insmod part_gpt
            insmod fat
            search --no-floppy --fs-uuid --set=root 1C4D-64E1
            chainloader /efi/Microsoft/Boot/bootmgfw.efi
          }
          menuentry "Reboot" {
            reboot
          }
          menuentry "Poweroff" {
            halt
          }
          menuentry 'UEFI Firmware Settings' --id 'uefi-firmware' {
            fwsetup
          }}
        '';
      };
    };
  };
}
