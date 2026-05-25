# k - my personal macbook pro M1 max, 64GB RAM
{ config, ... }:
{
  configurations.darwin.k.module = {
    imports = builtins.attrValues config.flake.modules.darwin;

    kriswill = {
      enable = true;
      dnsmasq.enable = true;
    };

    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.overlays = builtins.attrValues config.flake.overlays;

    home-manager.users.k.kriswill.podman-desktop.enable = true;
  };
}
