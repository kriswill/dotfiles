# This option is missing from nix-darwin config
{
  lib,
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
