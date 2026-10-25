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
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Games/battlenet";
      description = ''
        Compat data directory (Proton's `STEAM_COMPAT_DATA_PATH`); the Wine
        prefix is its `pfx/`. `null` means `$XDG_DATA_HOME/battlenet`
        (`~/.local/share/battlenet`), resolved per user at run time; a
        relative path is under each user's home. Proton creates the directory
        on first run, and `BATTLENET_PREFIX` overrides it for one run. An umu
        prefix works too: point at its `pfx` directory, since umu leaves a
        `pfx -> .` link inside it.
      '';
    };

    cpus = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "0-5,12-17";
      description = ''
        CPUs the whole session runs on, as a `taskset -c` list. That covers
        Battle.net, WoW and everything else Battle.net starts, Proton and the
        wineserver: they all inherit the affinity. The launcher also sets
        `WINE_CPU_TOPOLOGY` from the list (unless it's already set), so Wine
        reports only these CPUs. Otherwise a program that sets its affinity to
        "all processors" spreads back over every CPU, as WoW did. Wine reports
        each listed CPU as a separate core. On an AMD X3D CPU, give the 3D
        V-Cache CCD's CPUs (those sharing the large L3; see
        `/sys/devices/system/cpu/cpu*/cache/index3/shared_cpu_list`).
        `null` leaves affinity alone. `BATTLENET_CPUS` overrides it for one
        run, and an empty value turns pinning off.
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
      description = ''
        Extra environment variables for Proton. They are defaults: a variable
        already set when `battlenet` runs wins, so
        `PROTON_ENABLE_WAYLAND=0 battlenet` overrides
        `PROTON_ENABLE_WAYLAND = "1"` for one run.
      '';
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
          cpus
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
