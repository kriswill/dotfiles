{ pkgs, ... }:

{
  boot = {
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
    # Quiet boot
    initrd.verbose = false;
    consoleLogLevel = 3;
    kernelParams = [
      "quiet"
      "systemd.show_status=auto"
      "udev.log_level=3"
      "video=1920x1200"
    ];
    # plymouth = {
    #   enable = true;
    #   themePackages = [ pkgs.adi1090x-plymouth-themes ];
    #   theme = "loader";
    # };
  };
}
