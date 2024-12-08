{ config, inputs, pkgs, ... }:
{
  imports = [ ./disko.nix ];
  home-manager.profilesDir = ../../home;
}
