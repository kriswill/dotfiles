{ config, pkgs, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "quiet"
      # "systemd.show_status=auto"
      # "udev.log_level=3"
      "noatime"
      "video=1920x1200"
    ];

    consoleLogLevel = 3;
    kernelModules = [ "kvm-intel" ];
    supportedFilesystems = [ "ntfs" ]; # for windows disks

    initrd = {
      # Quiet boot
      verbose = false;
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "uas"
        "sd_mod"
      ];
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
        devices = [ "nodev" ];
        useOSProber = true;
        # menuentry "Windows 10" --class windows --class os {
        #   insmod part_gpt
        #   insmod ntfs
        #   search --no-floppy --fs-uuid --set=root 1C4D-64E1
        #   chainloader /efi/Microsoft/Boot/bootmgfw.efi
        # }
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

    # enables OBS virtual camera
    extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];

    # plymouth = {
    #   enable = true;
    #   themePackages = [ pkgs.adi1090x-plymouth-themes ];
    #   theme = "loader";
    # };
  };
}
