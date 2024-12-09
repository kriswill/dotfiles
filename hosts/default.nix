{ inputs, lib, ... }:
{
  yoda = lib.mkHost {
    inherit inputs;
    hostName = "yoda";
    gpu = "nvidia";
    cpu = "intel";
    users = [ "k" ];
    desktop = "hyprland";
    platform = "x86_64-linux";
    stateVersion = "25.05";
    configDir = ./yoda;
  };
}
