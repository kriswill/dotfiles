# mini - my personal mac mini M1, 16GB RAM
{ config, ... }:
{
  configurations.darwin.mini.module = {
    imports = builtins.attrValues config.flake.modules.darwin;

    kriswill = {
      enable = true;
      dnsmasq.enable = true;
    };

    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.overlays = builtins.attrValues config.flake.overlays;
  };
}
