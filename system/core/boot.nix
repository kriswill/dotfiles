{
  pkgs,
  config,
  ...
}: {
  boot = {
    # bootspec.enable = true;

    initrd = {
      # systemd.enable = true;
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "uas" "sd_mod" ];
      supportedFilesystems = ["ext4"];
      kernelModules = [ ];
    };

    # use latest kernel
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "kvm-intel" ];
    supportedFilesystems = [ "ntfs" ]; # for windows disks
    consoleLogLevel = 3;
    kernelParams = [
      "quiet"
      "noatime"
      "video=1920x1200"
      # "systemd.show_status=auto"
      # "rd.udev.log_level=3"
    ];

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
    # plymouth = {
    #   enable = true;
    #   themePackages = [ pkgs.adi1090x-plymouth-themes ];
    #   theme = "loader";
    # };
  };
}
