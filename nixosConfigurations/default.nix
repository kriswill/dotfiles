{
  lib,
  inputs,
  outputs,
  ...
}:
let
  slib = inputs.snowglobe-lib.lib;
in
{
  nebula = slib.mkNixosHost {
    hostname = "nebula";
    cpu-vendor = "amd";
    gpu-vendors = [ "nvidia" ];
    firmware = "UEFI";
    isVM = false;
    configDir = ./nebula;
    specialArgs = { inherit inputs; };
    modules = [ outputs.nixosModules.default ];
    stateVersion = "26.05";
  };
}
