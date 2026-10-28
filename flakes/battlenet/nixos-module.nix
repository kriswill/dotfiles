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

    confineSlices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "app.slice" ];
      description = ''
        User slices held to the CPUs outside `cpus` while a Battle.net
        session runs, so builds and other work leave the game's CPUs alone.
        Affinity can't do that for programs started elsewhere, such as a
        compiler cache's server; a cgroup cpuset can. The launcher that
        starts the session sets each slice's `AllowedCPUs` to the online CPUs
        outside `cpus` and clears it when the session ends (`battlenet kill`
        clears it too). Every launcher invocation that starts Wine runs it in
        a transient scope in `battlenet.slice`, so the game is never in a
        confined slice, even when started from a terminal. Needs `cpus`.

        The user's systemd needs the `cpuset` controller for this, so a
        non-empty list adds `cpuset` to `user@.service`'s `Delegate=`. A
        rebuild doesn't restart `user@.service`, so the delegation can take
        until the next login. Until then the launcher says confinement isn't
        active yet and runs without it. `BATTLENET_CONFINE` (space-separated
        slices) overrides the list for one run, and an empty value turns
        confinement off.
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
          confineSlices
          locale
          icon
          environment
          ;
      };
    }
    (lib.mkIf cfg.enable {
      environment.systemPackages = [ cfg.package ];
    })
    (lib.mkIf (cfg.enable && cfg.confineSlices != [ ]) {
      assertions = [
        {
          assertion = cfg.cpus != null;
          message = "programs.battlenet.confineSlices needs programs.battlenet.cpus: the slices are held to the CPUs outside it.";
        }
        {
          assertion = !lib.elem "battlenet.slice" cfg.confineSlices;
          message = "programs.battlenet.confineSlices can't include battlenet.slice: the session runs in it.";
        }
      ];
      # The user's systemd can only set AllowedCPUs on its slices with the
      # cpuset controller delegated to it. Upstream's user@.service delegates
      # `pids memory cpu`; this is that list plus cpuset, written in full so
      # it holds whether a drop-in's list adds to the unit's or replaces it.
      # A switch doesn't restart user@.service, so this can take until the
      # next login to reach the user manager. (A switch does re-execute
      # running user managers, which re-read their controllers then, so it
      # may arrive sooner.)
      systemd.services."user@".serviceConfig.Delegate = "pids memory cpu cpuset";
    })
  ];
}
