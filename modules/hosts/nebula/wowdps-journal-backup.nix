# Hourly check for the wowdps-suite coordinator journal backup: a declarative
# copy of the suite's tools/journal-backup.{service,timer} (~/src/wowdps-suite,
# install notes in tools/journal-backup.md). The suite's own 20-hour
# `--if-due` window decides whether a run actually snapshots; the saved plan
# (local rotation under ~/.local/state/wowdps-suite/journal-backups, mirror to
# /mnt/nas/wowdps-journal — nas-mount.nix) was set up once with `--save`.
#
# Exit 3 = local snapshot done, NAS mirror skipped (the log says why); the
# timer retries just the mirror on the next tick.
#
# ConditionUser=k: the units point at k's checkout and dev shell. The NAS
# automount is a system unit, so no ordering here — the first access mounts it.
{
  configurations.nixos.nebula.module = {
    systemd.user.services.journal-backup = {
      description = "Back up and mirror the coordinator journal";
      unitConfig.ConditionUser = "k";
      # Trigger-started oneshot: don't let a switch wait on a backup in flight
      # (knowledge/decisions/user-oneshots-skip-switch-restart.md).
      restartIfChanged = false;
      # /run/wrappers + the system profile, as in the suite's unit (devenv and
      # whatever the dev shell shells out to).
      path = [
        "/run/wrappers"
        "/run/current-system/sw"
      ];
      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = "%h/src/wowdps-suite";
        ExecStart = "/run/current-system/sw/bin/devenv shell -- suite journal backup --if-due";
        Nice = 10;
        IOSchedulingClass = "idle";
        UMask = "0077";
        TimeoutStartSec = "15min";
      };
    };

    systemd.user.timers.journal-backup = {
      description = "Check whether the coordinator journal backup is due";
      wantedBy = [ "timers.target" ];
      unitConfig.ConditionUser = "k";
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "10min";
      };
    };
  };
}
