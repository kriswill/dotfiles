{ inputs, lib, ... }:
{
  imports = [
    ./disko.nix
    ./boot.nix
    # ./nix.nix
    ./hardware-configuration.nix
    ./sddm.nix
    inputs.nix-config.nixosProfiles.gaming
  ];
  time.timeZone = "America/Los_Angeles";
  home-manager.profilesDir = ../../home;
  modules = {
    onepassword.enable = true;
    sops.enable = true;
  };
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
