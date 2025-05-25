{
  lib,
  inputs,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkProgramOption;
in
{
  options.programs.nh = mkProgramOption {
    programName = "nh";
    description = "Nix Helper";
    inherit pkgs;
  };
}
