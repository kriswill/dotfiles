{
  inputs,
  config,
  pkgs,
  lib,
  packages,
  ...
}:

{
  imports = [ inputs.grub2-themes.nixosModules.default ];
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "quiet"
      # "systemd.show_status=auto"
      # "udev.log_level=3"
      "noatime"
      "video=DP-0:3440x1440@99.9"
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
        # Catppuccin
        # theme = lib.mkForce (pkgs.fetchFromGitHub {
        #   owner = "catppuccin";
        #   repo = "grub";
        #   rev = "88f6124757331fd3a37c8a69473021389b7663ad";
        #   sha256 = "sha256-e8XFWebd/GyX44WQI06Cx6sOduCZc5z7/YhweVQGMGY=";
        # } + "/src/catppuccin-mocha-grub-theme");
        # theme = pkgs.fetchzip {
        #   url = "https://github.com/AdisonCavani/distro-grub-themes/raw/master/themes/nixos.tar";
        #   hash = "sha256-KQAXNK6sWnUVwOvYzVfolYlEtzFobL2wmDvO8iESUYE=";
        #   stripRoot = false;
        # };

        #theme = packages.distro-grub-themes-nixos;

        # gfxmodeEfi = "3440x1440";
        extraEntries = ''
          menuentry "Reboot" {
            reboot
          }
          menuentry "Poweroff" {
            halt
          }
        '';
        extraConfig = ''
          GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet acpi_enforce_resources=lax nvidia_drm.modeset=1"
        '';
        # doesn't work?
        # GRUB_GFXMODE=3440x1440,auto
        # GRUB_INIT_TUNE="1750 523 1 392 1 523 1 659 1 784 1 1047 1 784 1 415 1 523 1 622 1 831 1 622 1 831 1 1046 1 1244 1 1661 1 1244 1 466 1 587 1 698 1 932 1 1195 1 1397 1 1865 1 1397 1"
      };
      grub2-theme = {
        enable = true;
        theme = "stylish";
        footer = true;
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
