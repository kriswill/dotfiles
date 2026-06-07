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
  snowglobe-lib.desktop.niri.enable = true;

  # custom profiles
  snowglobe-lib.profiles.hardware-tools.enable = true;
  snowglobe-lib.profiles.gaming.enable = true;
  snowglobe-lib.profiles.office.enable = true;
  snowglobe-lib.profiles.hacker-mode.enable = true;
  snowglobe-lib.profiles.nix-tools.enable = true;
  snowglobe-lib.profiles.harden.enable = true;

  # Don't trust cache server
  substituters."nix-store.homelab.earthgman.dev".enable = false;

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
  ];

  # Helium is my browser; drop the snowglobe-lib default browsers I don't use.
  # Both are enabled via mkDefault upstream (firefox by the niri desktop module
  # -> librewolf; chromium by the office profile -> ungoogled-chromium), so a
  # plain override here wins.
  programs.firefox.enable = false;
  programs.chromium.enable = false;

  # Ghostty is my terminal. The niri desktop module enables alacritty as the
  # default terminal via mkDefault, so disabling it here (plain override) wins.
  # The niri keybind to launch it lives in ~/.config/niri/config.kdl.
  programs.ghostty.enable = true;
  programs.alacritty.enable = false;

  programs._1password.enable = true;
  programs._1password-gui.enable = true;
  programs.kanshi = {
    enable = true;
    systemd.enable = true;
  	};

  # Allow generic-Linux dynamically-linked binaries (e.g. user-installed
  # claude-code) to find a dynamic linker. https://nix.dev/permalink/stub-ld
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
    ];
  };

  programs.discord = {
  	enable = true;
	package = pkgs.discord;
  	};
}
