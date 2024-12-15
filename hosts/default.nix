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
  nixos-arm = lib.mkHost {
    inherit inputs;
    hostName = "nixos-arm";
    vm = true;
    users = [ "k" ];
    desktop = "i3,hyprland";
    platform = "aarch64-linux";
    stateVersion = "25.05";
    configDir = ./nixos-arm;
  };
}
