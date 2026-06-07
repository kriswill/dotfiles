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
