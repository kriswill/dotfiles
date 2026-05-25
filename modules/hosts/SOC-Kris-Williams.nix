# SOC-Kris-Williams - my work Apple M2 Pro, 32GB RAM
# hostname enforced by IT
{ config, ... }:
{
  configurations.darwin.SOC-Kris-Williams.module = {
    imports = builtins.attrValues config.flake.modules.darwin;

    kriswill = {
      enable = true;
      alias-en0.enable = true;
      dnsmasq.enable = true;
    };

    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.overlays = builtins.attrValues config.flake.overlays;

    home-manager.users.k.kriswill.podman-desktop.enable = true;
  };
}
