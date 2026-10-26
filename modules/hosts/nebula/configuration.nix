{
  configurations.nixos.nebula.module =
    {
      pkgs,
      lib,
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
      # (renamed from libvirtd-qemu in snowglobe-factory f0135ce; same
      # libvirtd + qemu_kvm + virt-manager payload)
      snowglobe-factory.qemu.enable = true;

      # custom profiles
      snowglobe-factory.profiles.gaming.enable = true;
      # Off since 2026-10-25: its FHS runtime was the only thing pulling in
      # ffmpeg 6.1.6 (39 nixploit findings).
      programs.lutris.enable = false;
      snowglobe-factory.profiles.office.enable = true;
      # snowglobe's default (libreoffice-fresh) is a deprecated nixpkgs alias
      # since the upstream fresh/still split ended — it warns on every eval.
      # Drop this override if snowglobe-factory moves to libreoffice-stable.
      programs.libreoffice.package = pkgs.libreoffice-stable;
      snowglobe-factory.profiles.hacker-mode.enable = true;
      # Off since 2026-10-25, with VLC from snowglobe's desktop layer: the two
      # were the only things pulling in ffmpeg 7.1.5 (41 nixploit findings).
      # The tor daemon hacker-mode also enables stays.
      programs.tor-browser.enable = false;
      programs.vlc.enable = false;
      # nix-tools profile: dropped upstream (snowglobe-factory b0a0d97b, 2026-10);
      # its package payload is inlined into environment.systemPackages below.
      snowglobe-factory.profiles.harden.enable = true;
      # corefreq's out-of-tree module doesn't build on kernel 7.1 (CPPC struct
      # field reference_perf → reference). Disable until upstream catches up.
      # ponytail: re-enable when corefreq builds against 7.1.
      programs.corefreq.enable = false;

      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;

      services = {
        displayManager.defaultSession = "hyprland-uwsm";
        polkit-gnome.enable = false;
        opensnitch.enable = true; # application firewall daemon
      };
      # Don't trust cache server
      substituters."nix-store.earthgman.dev".enable = false;

      # Dual-boot: Windows lives on a separate disk with its own ESP. systemd-boot
      # only lists entries on its own ESP, which is why nebula stays on
      # snowglobe's GRUB. A static chainload entry replaces os-prober and gives
      # the same menu item without rescanning (and root-mounting) the other
      # disk on every rebuild, and without os-prober's
      # `lsblk: /dev/mapper/no*[0-9]` noise. The UUID is the Windows disk's ESP
      # (nvme1n1p1, vfat); the path is what os-prober found there. mkBefore puts
      # it ahead of snowglobe's Reboot/Poweroff/firmware/Memtest entries.
      boot.loader.grub.useOSProber = false;
      boot.loader.grub.extraEntries = lib.mkBefore ''
        menuentry "Windows Boot Manager" --class windows --class os {
          insmod part_gpt
          insmod fat
          search --no-floppy --fs-uuid --set=root B658-8653
          chainloader /efi/Microsoft/Boot/bootmgfw.efi
        }
      '';

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
        # 1Password service-account token, read-only on the Automation vault
        # (holds only the gh CLI token). Consumed by the gh wrapper
        # (overlays/gh-op.nix) for prompt-free `op read`. Rotate ~every 90d:
        # 1password.com → Developer → Service Accounts → nebula-gh.
        op-sa-token = {
          owner = "k";
          mode = "0400";
        };
      };

      # No channels: drops the dead /nix/var/nix/profiles/per-user/root/channels
      # NIX_PATH entry that every nix invocation (e.g. `, foo`) warned about.
      nix.channel.enable = false;

      environment.systemPackages = [
        # git + gh/delta/diffnav/difftastic/git-lfs come from modules/nixos/git.nix
        pkgs.nvtopPackages.nvidia # GPU monitor; `, nvtop` picks a non-NVIDIA build that sees no GPU
        pkgs.cliphist # clipboard history (used with fuzzel --dmenu)
        pkgs.fd # fast file finder
        pkgs.gimp # raster image editor
        pkgs.kdePackages.breeze-icons
        pkgs.kitten # fastfetch's kitty-icat logo renderer (standalone binary, not the kitty terminal)
        pkgs.opensnitch-ui # prompt/tray UI for the opensnitch daemon (services.opensnitch)
        pkgs.rose-pine-cursor # Xcursor twin of the hyprcursor theme, for XWayland client cursors (Steam); selected via XCURSOR_THEME in environment.lua
        pkgs.rose-pine-hyprcursor # native hyprcursor theme (BreezeX shape, Rose Pine palette); selected via HYPRCURSOR_THEME in hyprland.lua
        pkgs.wowup # WowUp-CF (WoW addon manager); WoW path defaults in pkgs/wowup.nix
      ]
      # snowglobe-factory dropped its hardware-tools profile; keep its payload.
      ++ (with pkgs; [
        usbutils
        smartmontools
        hdparm
        nvme-cli
        lm_sensors
        pciutils
        lshw
        hwinfo
        inxi
        vdpauinfo
        libva-utils
        mesa-demos
        vulkan-tools
        clinfo
      ])
      # snowglobe-factory dropped its nix-tools profile too (b0a0d97b, 2026-10);
      # keep its payload. direnv (the profile's other half) is already explicit
      # in modules/nixos/direnv.nix; deadnix/statix/nixfmt also live in the dev
      # shell (modules/dev.nix) — these are the system-wide copies.
      ++ (with pkgs; [
        nurl
        nix-prefetch-git
        deadnix
        nixpkgs-hammering
        statix
        nix-init
        nix-update
        nixpkgs-review
        nixfmt
      ]);

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
        # Chromium's VA-API decode through nvidia-vaapi-driver shows stream
        # frames out of order (video jumps back/forth, audio fine); the CPU
        # decodes Discord streams with ease.
        package = pkgs.discord.override {
          commandLineArgs = "--disable-accelerated-video-decode";
        };
      };

      programs.vesktop = {
        enable = true;
        # Same NVIDIA VA-API stream glitch as discord above; nixpkgs' vesktop
        # has no commandLineArgs, so wrap it (its .desktop Exec is by name).
        package = pkgs.symlinkJoin {
          name = "vesktop-sw-decode";
          paths = [ pkgs.vesktop ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/vesktop --add-flags --disable-accelerated-video-decode
          '';
        };
      };
      programs.gajim.enable = true;
      programs.stoat-desktop.enable = true; # snowglobe: Stoat (Revolt) chat client
      programs.gthumb.enable = true;
    }

  ;
}
