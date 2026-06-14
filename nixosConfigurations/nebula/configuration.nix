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
  snowglobe-lib.desktop.niri.enable = true;
  snowglobe-lib.desktop.hyprland.enable = true;

  # custom profiles
  snowglobe-lib.profiles.hardware-tools.enable = true;
  snowglobe-lib.profiles.gaming.enable = true;
  snowglobe-lib.profiles.office.enable = true;
  snowglobe-lib.profiles.hacker-mode.enable = true;
  snowglobe-lib.profiles.nix-tools.enable = true;
  snowglobe-lib.profiles.harden.enable = true;

  # The gaming profile enables programs.gamescope, but nixpkgs builds gamescope
  # with the FROG Vulkan WSI layer OFF by default (enableWsi ? false). Without
  # that layer a Vulkan/DXVK client inside `gamescope --hdr-enabled` can't signal
  # HDR, so HDR never engages (and SDR content gets mapped into the HDR container,
  # causing the color shifts seen on the OLED). Turning this on builds the layer
  # and drops VkLayer_FROG_gamescope_wsi.{x86_64,i686}.json onto the system Vulkan
  # implicit-layer path, where Steam's pressure-vessel imports it. See
  # docs/hdr-hyprland-june-2026.md. NOTE: driver 595.45.04 is just below 595.58.03
  # (native HDR-WSI on NVIDIA); the layer is required regardless, but if HDR still
  # comes out washed/SDR, bumping the NVIDIA driver is the next lever.
  programs.gamescope.enableWsi = true;

  # snowglobe defaults the NVIDIA driver to nvidiaPackages.beta (595.45.04 — older
  # than production and PRE native HDR-WSI). Native HDR-WSI on NVIDIA landed in
  # 595.58.03, so override to the production branch (595.80) to get HDR working for
  # gamescope/Proton. Chosen over `latest` (610.43.02) deliberately: 610 is a
  # new-feature branch with confirmed RTX 5080 regressions (Wayland explicit-sync
  # memory leak; DRM color-pipeline HDR fails on Blackwell over DP). Keep
  # hardware.nvidia.open = true — REQUIRED for Blackwell (no proprietary module).
  # See docs/hdr-hyprland-june-2026.md.
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;

  services = {
    displayManager.defaultSession = "hyprland-uwsm";
  };
  # Don't trust cache server
  substituters."nix-store.homelab.earthgman.dev".enable = false;

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

  environment.etc = {
    "ssh/ssh_host_ed25519_key.pub".source = ./ssh_host_ed25519_key.pub;
    "ssh/ssh_host_rsa_key.pub".source = ./ssh_host_rsa_key.pub;
  };

  sops.secrets = {
    ssh_host_ed25519_key.path = "/etc/ssh/ssh_host_ed25519_key";
    ssh_host_rsa_key.path = "/etc/ssh/ssh_host_rsa_key";
  };

  environment.systemPackages = [
    pkgs.helium
    pkgs.gh # GitHub CLI
    pkgs.cliphist # clipboard history (used with fuzzel --dmenu)
    pkgs.kdePackages.breeze-icons
    pkgs.swaybg # paints the niri desktop wallpaper (spawned in niri config)
    pkgs.hyprpaper # paints the Hyprland desktop wallpaper (spawned in hyprland.lua)
  ];

  programs.firefox.enable = false;
  programs.chromium.enable = false;
  programs.ghostty.enable = true;
  programs.alacritty.enable = false;

  programs._1password.enable = true;
  programs._1password-gui.enable = true;
  programs.kanshi = {
    enable = true;
    systemd.enable = true;
  };

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
}
