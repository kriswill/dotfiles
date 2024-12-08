{ lib, ... }:
{
  imports = [ ./disko.nix ];
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
}
