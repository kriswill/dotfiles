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
      type = lib.types.nullOr (lib.types.strMatching "[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*");
      default = null;
      example = "0-5,12-17";
      description = ''
        CPUs the whole session runs on, as a `taskset -c` list of CPUs and
        ranges (no strides: confinement works out the CPUs outside it). That
        covers Battle.net, WoW and everything else Battle.net starts, Proton
        and the wineserver: they all inherit the affinity. The launcher also
        sets `WINE_CPU_TOPOLOGY` from the list (unless it's already set), so
        Wine reports only these CPUs. Otherwise a program that sets its
        affinity to "all processors" spreads back over every CPU, as WoW did.
        Wine reports each listed CPU as a separate core. On an AMD X3D CPU,
        give the 3D V-Cache CCD's CPUs (those sharing the large L3; see
        `/sys/devices/system/cpu/cpu*/cache/index3/shared_cpu_list`).
        `null` leaves affinity alone. `BATTLENET_CPUS` overrides it for one
        run, and an empty value turns pinning off.
      '';
    };

    confineSlices = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9_.-]+\\.slice");
      default = [ ];
      example = [ "app.slice" ];
      description = ''
        User slices held to the CPUs outside `cpus` while a Battle.net
        session runs, so the work in them leaves the game's CPUs alone.
        Affinity can't do that for programs started elsewhere, such as a
        compiler cache's server; a cgroup cpuset can. Needs `cpus`. The game
        runs in `battlenet.slice`, which can't be listed. The flake's README
        has the details.

        A non-empty list adds `cpuset` to `user@.service`'s `Delegate=`, so
        the user's systemd can set it. The switch hands that to running user
        managers when it re-executes them. Nix builds run in the system's
        `nix-daemon.service`, outside every user slice: see
        `confineNixDaemon`. `BATTLENET_CONFINE` (space-separated) overrides
        the list for one run, and an empty value turns confinement off.
      '';
    };

    confineNixDaemon = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Also hold `nix-daemon.service`, which runs the Nix builds, to the CPUs
        outside `cpus` while a session runs. A user can't set a system unit's
        `AllowedCPUs`, so this adds a polkit rule that lets members of the
        `users` group start `battlenet-confine-nix@.service`, which sets it
        as root and accepts only the online CPUs outside `cpus`, or none.
        Each user's launcher counts only that user's sessions, so this suits
        a machine with one player. Needs `cpus` and polkit.
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
          confineNixDaemon
          locale
          icon
          environment
          ;
        # The launcher's systemctl and systemd-run, from the systemd it talks to.
        systemd = config.systemd.package;
      };
    }
    (lib.mkIf cfg.enable {
      environment.systemPackages = [ cfg.package ];
      # battlenet-confine@.service and battlenet-confine-nix@.service.
      systemd.packages = [ cfg.package ];
    })
    (lib.mkIf (cfg.enable && (cfg.confineSlices != [ ] || cfg.confineNixDaemon)) {
      assertions = [
        {
          assertion = cfg.cpus != null;
          message = "programs.battlenet.confineSlices and confineNixDaemon need programs.battlenet.cpus: they hold work to the CPUs outside it.";
        }
      ];
    })
    (lib.mkIf (cfg.enable && cfg.confineSlices != [ ]) {
      assertions = [
        {
          assertion = !lib.elem "battlenet.slice" cfg.confineSlices && !lib.elem "-.slice" cfg.confineSlices;
          message = "programs.battlenet.confineSlices can't include battlenet.slice or the root slice (-.slice): the session runs inside them.";
        }
      ]
      # Releasing a target writes an empty runtime AllowedCPUs=, which
      # overrides a configured value until reboot.
      ++ map (slice: {
        assertion =
          !(config.systemd.user.slices.${lib.removeSuffix ".slice" slice}.sliceConfig or { }) ? AllowedCPUs;
        message = "programs.battlenet.confineSlices can't include ${slice}: it sets AllowedCPUs itself, which the confinement's release would clear until reboot.";
      }) cfg.confineSlices;
      # The user's systemd can only set AllowedCPUs on its slices with the
      # cpuset controller delegated to it. Upstream's user@.service delegates
      # `pids memory cpu`; this is that list plus cpuset, written in full so
      # it holds whether a drop-in's list adds to the unit's or replaces it.
      # A switch doesn't restart user@.service, but it re-executes running
      # user managers, which read their controllers again then (seen on
      # nebula, 2026-10-27).
      systemd.services."user@".serviceConfig.Delegate = "pids memory cpu cpuset";
    })
    (lib.mkIf (cfg.enable && cfg.confineNixDaemon) {
      assertions = [
        {
          assertion = config.security.polkit.enable;
          message = "programs.battlenet.confineNixDaemon needs security.polkit.enable: a polkit rule lets users start battlenet-confine-nix@.service.";
        }
        {
          assertion = !(config.systemd.services.nix-daemon.serviceConfig or { }) ? AllowedCPUs;
          message = "programs.battlenet.confineNixDaemon can't be used while nix-daemon.service sets AllowedCPUs itself: the confinement's release would clear it until reboot.";
        }
      ];
      # Starting battlenet-confine-nix@CPUS.service only sets
      # nix-daemon.service's AllowedCPUs to CPUS, which its script accepts
      # only as the online CPUs outside `cpus`, or "none".
      security.polkit.extraConfig = ''
        polkit.addRule(function (action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units" &&
              action.lookup("verb") == "start" &&
              /^battlenet-confine-nix@([0-9_-]+|none)\.service$/.test(action.lookup("unit")) &&
              subject.isInGroup("users")) {
            return polkit.Result.YES;
          }
        });
      '';
    })
  ];
}
