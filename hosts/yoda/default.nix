{ config, lib, ... }:
{
  imports = [ ./disko.nix ./hardware-configuration.nix ];
  home-manager.profilesDir = ../../home;
  modules = {
    onepassword.enable = true;
    sops.enable = true;
  };
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub.efiInstallAsRemovable = true;
  sops = {
    # default location
    # /var/lib/sops-nix/keys.txt
    defaultSopsFile = lib.mkForce ./secrets.yaml;
    secrets.k-password = {
      neededForUsers = true;
    };
  };
  # programs.hyprland = {
  #   withUWSM = true;
  # };
  # wayland.windowManager.hyprland.systemd.enable = false;
}
