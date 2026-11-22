# The fastfetch module. One file for both OSes: it is exported as
# nixosModules.fastfetch and darwinModules.fastfetch (and `default` in each).
#
# It says which logo to show and builds the wrapped fastfetch
# (./package.nix) from the host's own pkgs, so the fastfetch underneath is
# the one the rest of the system uses, overlays included.
#
# It installs nothing. Where fastfetch comes from differs per system: put
# `programs.fastfetch.finalPackage` in environment.systemPackages, or hand it
# to whichever module already installs fastfetch. It also declares no
# `enable` or `package`, so it can sit beside a module that owns those names
# under programs.fastfetch.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.fastfetch;
in
{
  options.programs.fastfetch = {
    logo = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Nebula.png";
      description = ''
        Logo image filename under ~/.config/fastfetch/, passed as `--logo`,
        which beats config.jsonc's `source`. null leaves the logo to
        config.jsonc.
      '';
    };
    logoPaddingTop = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = "Blank rows above the logo.";
    };
    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = ''
        fastfetch wrapped with the logo flags and the kitten shim, built
        from this system's `pkgs.fastfetch`.
      '';
    };
  };

  config.programs.fastfetch.finalPackage = pkgs.callPackage ./package.nix {
    inherit (cfg) logo;
    paddingTop = cfg.logoPaddingTop;
  };
}
