# Pure helpers merged onto nixpkgs lib (see modules/lib.nix). Kept outside
# ./modules so import-tree does not treat it as a flake-parts module.
{ lib }:
let
  inherit (lib)
    mkEnableOption
    mkPackageOption
    optionalString
    ;
in
{
  kanagawa = import ./kanagawa;

  mkProgramOption =
    {
      pkgs,
      programName,
      packageName ? programName,
      description ? null,
      extraPackageArgs ? { },
    }:
    {
      enable = mkEnableOption (programName + " " + optionalString (description != null) description);
      package = mkPackageOption pkgs packageName extraPackageArgs;
    };
}
