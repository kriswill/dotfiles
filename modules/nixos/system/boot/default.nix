{ config, lib, options, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.internal) mkBoolOpt;

  cfg = config.k.system.boot;
in
{
  options.k.system.boot = {
    enable = mkBoolOpt false "Whether or not to enable booting.";
    plymouth = mkBoolOpt false "Whether or not to enable plymouth boot splash.";
    secureBoot = mkBoolOpt false "Whether or not to enable secure boot.";
  };

  config = mkIf cfg.enable {
    /*
      environment.systemPackages = with pkgs;  [
      efibootmgr
      efitools
      efivar
      fwupd
      ] ++ lib.optionals cfg.secureBoot [
      sbctl
      ];
    */
    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/vda";
    boot.loader.grub.useOSProber = true;

    /*
      boot = {
      kernelParams = lib.optionals cfg.plymouth [ "quiet" ];

      lanzaboote = mkIf cfg.secureBoot {
        enable = true;
        pkiBundle = "/etc/secureboot";
      };

      loader = {
        efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint = "/boot";
        };

        systemd-boot = {
          enable = !cfg.secureBoot;
          configurationLimit = 20;
          editor = false;
        };
      };

      plymouth = {
        enable = cfg.plymouth;
        theme = "catppuccin-macchiato";
        themePackages = [ pkgs.catppuccin-plymouth ];
      };
      };

      services.fwupd.enable = true;
    */
  };
}
