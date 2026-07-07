{
  configurations.nixos.nebula.module =
    {
      pkgs,
      # lib,
      config,
      ...
    }:
    {
      i18n.defaultLocale = "en_US.UTF-8";
      services.xserver.xkb.layout = "us";
      time.timeZone = "America/Los_Angeles";
      # Hyprland (the host's only desktop) is configured in ./hyprland.nix,
      # which also asserts the shared snowglobe desktop layer that niri used to
      # pull in.
      # (renamed from libvirtd-qemu in snowglobe-lib f0135ce; same
      # libvirtd + qemu_kvm + virt-manager payload)
      snowglobe-lib.qemu.enable = true;

      # custom profiles
      snowglobe-lib.profiles.hardware-tools.enable = true;
      snowglobe-lib.profiles.gaming.enable = true;
      snowglobe-lib.profiles.office.enable = true;
      snowglobe-lib.profiles.hacker-mode.enable = true;
      snowglobe-lib.profiles.nix-tools.enable = true;
      snowglobe-lib.profiles.harden.enable = true;
      # corefreq's out-of-tree module doesn't build on kernel 7.1 (CPPC struct
      # field reference_perf → reference). Disable until upstream catches up.
      # ponytail: re-enable when corefreq builds against 7.1.
      programs.corefreq.enable = false;

      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;

      services = {
        displayManager.defaultSession = "hyprland-uwsm";
        polkit-gnome.enable = false;
      };
      # Don't trust cache server
      substituters."nix-store.earthgman.dev".enable = false;

      # Dual-boot: let GRUB probe other disks for Windows/other OSes and add them to
      # the menu. Required because Windows lives on a separate disk/ESP that the
      # bootloader won't surface otherwise. (This is why nebula stays on snowglobe's
      # GRUB rather than systemd-boot, which only lists entries on its own ESP.)
      boot.loader.grub.useOSProber = true;

      # Run the GRUB menu at the panel's native mode and hand that framebuffer
      # straight to the kernel (gfxpayloadEfi defaults to "text" on UEFI, which
      # otherwise drops resolution at boot). "auto" follows the EDID-preferred mode.
      boot.loader.grub.gfxmodeEfi = "3440x1440x32";
      boot.loader.grub.gfxpayloadEfi = "keep";

      # Make the systemd-initrd emergency shell usable on-console. The harden
      # profile locks the root account, so when stage-1 drops to emergency mode
      # ("Cannot open access to console, the root account is locked") there is no
      # way to log in and debug — the only recovery is booting external media and
      # nixos-enter. This bit us on 2026-06-16: a nix-collect-garbage deleted older
      # generations whose closures GRUB still listed, so selecting one made
      # initrd-find-nixos-closure fail (resolve-in-root on a GC'd init= path, under
      # `set -e`) → emergency → locked shell. emergencyAccess = true grants
      # passwordless root in the initrd rescue/emergency shell only. Security note:
      # nebula's root fs is unencrypted ext4 (see disko.nix), so anyone with
      # physical access already has full data access — this does not widen the
      # threat model, it just makes recovery debuggable without a USB stick.
      boot.initrd.systemd.emergencyAccess = true;

      environment.etc = {
        "ssh/ssh_host_ed25519_key.pub".source = ./ssh_host_ed25519_key.pub;
        "ssh/ssh_host_rsa_key.pub".source = ./ssh_host_rsa_key.pub;
      };

      sops.secrets = {
        ssh_host_ed25519_key.path = "/etc/ssh/ssh_host_ed25519_key";
        ssh_host_rsa_key.path = "/etc/ssh/ssh_host_rsa_key";
      };

      environment.systemPackages = [
        # git + gh/delta/diffnav/difftastic/git-lfs come from modules/nixos/git.nix
        pkgs.cliphist # clipboard history (used with fuzzel --dmenu)
        pkgs.fd # fast file finder
        pkgs.gimp # raster image editor
        pkgs.kdePackages.breeze-icons
        pkgs.rose-pine-cursor # Xcursor twin of the hyprcursor theme, for XWayland client cursors (Steam); selected via XCURSOR_THEME in environment.lua
        pkgs.rose-pine-hyprcursor # native hyprcursor theme (BreezeX shape, Rose Pine palette); selected via HYPRCURSOR_THEME in hyprland.lua
        pkgs.umu-launcher # standalone Proton runner; launches Battle.net.desktop in GE-Proton without opening the Steam client
        pkgs.wowup # WowUp-CF (WoW addon manager); WoW path defaults in pkgs/wowup.nix
      ];

      programs.firefox.enable = false;
      programs.chromium.enable = false;
      programs.batsignal.enable = false;
      programs.gamescope.enableWsi = true;

      # gpg-agent comes from modules/nixos/gpg.nix (class-wide, mirrors darwin).

      systemd.packages = [ pkgs.hyprpolkitagent ];
      systemd.user.services.hyprpolkitagent.wantedBy = [ "graphical-session.target" ];

      # ghostty comes from modules/nixos/ghostty.nix (install + os.conf half of
      # the shared stow config).
      programs.alacritty.enable = false;

      programs._1password.enable = true;
      programs._1password-gui.enable = true;

      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          stdenv.cc.cc.lib
          zlib
        ];
      };

      programs.discord = {
        enable = true;
        # package = pkgs.discord;
      };

      programs.gajim.enable = true;
      programs.gthumb.enable = true;
      # vesktop (snowglobe's discord client) builds with pnpm, which nixpkgs
      # b5aa0fb marks insecure (CVE-2026-48995 + 6 more — pnpm CLI issues,
      # build-time-only exposure here). Remove once vesktop migrates off the
      # flagged pnpm (2026-07-03).
      nixpkgs.config.permittedInsecurePackages = [ "pnpm-10.29.2" ];
    }

  ;
}
