# This option is missing from nix-darwin config
{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkIf mkProgramOption;
  cfg = config.programs.nh;
in
{
  options.programs.nh = mkProgramOption {
    programName = "nh";
    description = "Nix Helper";
    inherit pkgs;
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
