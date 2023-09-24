{ pkgs, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_6_5;
    kernelParams = [
      "quiet"
      # "systemd.show_status=auto"
      # "udev.log_level=3"
      "noatime"
      "video=1920x1200"
    ];

    consoleLogLevel = 3;
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
    supportedFilesystems = [ "ntfs" ]; # for windows disks

    initrd = {
      # Quiet boot
      verbose = false;
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "uas" "sd_mod" ];
      kernelModules = [ ];
    };

    loader = {
      timeout = 5;

      efi = {
        # allows grub.efiInstallAsRemovable
        # canTouchEfiVariables = false;
        efiSysMountPoint = "/boot";
      };
      # 1) pick systemd-boot:
      # systemd-boot.enable = true;
      # 2) pick grub 2:
      grub = {
        enable = true;
        efiSupport = true;
        # efiInstallAsRemovable = true;
        devices = [ "nodev" ];
        useOSProber = true;
        # extraEntriesBeforeNixOS = true;
        # windows:
        # /dev/nvme0n1p2@/efi/Microsoft/Boot/bootmgfw.efi
        extraEntries = ''
          menuentry "Reboot" {
            reboot
          }
          menuentry "Poweroff" {
            halt
          }
        '';
      };
    };

    # plymouth = {
    #   enable = true;
    #   themePackages = [ pkgs.adi1090x-plymouth-themes ];
    #   theme = "loader";
    # };
  };
}
