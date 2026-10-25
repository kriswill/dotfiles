# NixOS module, exported as `nixosModules.battlenet` (and `default`).
# programs.battlenet.enable installs the `battlenet` launcher and its desktop
# entry, built by ./package.nix from these options against the system's pkgs.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.battlenet;
in
{
  options.programs.battlenet = {
    enable = lib.mkEnableOption "Battle.net, Blizzard's game launcher, run in Proton without Steam or umu";

    proton = lib.mkPackageOption pkgs "proton-ge-bin" {
      extraDescription = ''
        The Proton build that runs Battle.net: a package with a
        `steamcompattool` output, or a package holding a `proton` script.
        Battle.net depends on GE-Proton's no-Steam (`UMU_ID`) and
        `STORE=battlenet` handling.
      '';
    };

    prefix = lib.mkOption {
      type = lib.types.str;
      default = "Games/battlenet";
      example = ".local/share/Steam/steamapps/compatdata/3082075026/pfx";
      description = ''
        Compat data directory (Proton's `STEAM_COMPAT_DATA_PATH`); the Wine
        prefix is its `pfx/`. A relative path is under each user's home.
        Proton creates the directory on first run, and `BATTLENET_PREFIX`
        overrides it for one run. An umu prefix works too: point at its `pfx`
        directory, since umu leaves a `pfx -> .` link inside it.
      '';
    };

    locale = lib.mkOption {
      type = lib.types.str;
      default = "enUS";
      description = "Language passed to Blizzard's installer (`--lang`).";
    };

    icon = lib.mkOption {
      type = lib.types.str;
      default = "applications-games";
      example = "/home/alice/Pictures/battlenet.png";
      description = "Icon name or absolute path for the desktop entry.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        PROTON_ENABLE_WAYLAND = "1";
        PROTON_LOG = "1";
      };
      description = "Extra environment variables for Proton.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "The launcher built from these options.";
    };
  };

  config = lib.mkMerge [
    {
      programs.battlenet.package = pkgs.callPackage ./package.nix {
        inherit (cfg)
          proton
          prefix
          locale
          icon
          environment
          ;
      };
    }
    (lib.mkIf cfg.enable {
      environment.systemPackages = [ cfg.package ];
    })
  ];
}
