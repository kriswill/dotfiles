---
type: Decision
title: Confine app.slice While Battle.net Runs
description: 'While a Battle.net session runs, app.slice and nix-daemon.service are held to the CPUs outside the game''s with a cgroup cpuset, and the game runs in its own battlenet.slice scope, because affinity can''t reach work started elsewhere (the sccache server''s compilers, Nix builds); a StopWhenUnneeded unit that the session scopes uphold makes systemd, not the launcher, decide when it ends, cpuset is delegated to user@.service, and a polkit-gated root oneshot sets nix-daemon.service.'
tags: [battlenet, systemd, cgroups, cpu, polkit]
generated: { by: claude-code/opus-5.5, at: 2026-10-28T21:30:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/battlenet/README.md
    title: 'flakes/battlenet/README.md (keeping other work off those CPUs)'
  - id: systemd-resource-control
    resource: https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
    title: 'systemd.resource-control(5): AllowedCPUs=, Delegate='
  - id: systemd-unit
    resource: https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
    title: 'systemd.unit(5): StopWhenUnneeded=, Upholds=, Before='
  - id: systemd-run
    resource: https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html
    title: 'systemd-run(1): --scope, --slice=, --expand-environment='
  - id: systemd-run-source
    resource: https://github.com/systemd/systemd/blob/v262/src/run/run.c
    title: 'systemd v262 src/run/run.c (start_transient_scope)'
  - id: systemd-dbus-slice
    resource: https://github.com/systemd/systemd/blob/v262/src/core/dbus-slice.c
    title: 'systemd v262 src/core/dbus-slice.c (bus_slice_commit_properties)'
  - id: kernel-cgroup-v2
    resource: https://docs.kernel.org/admin-guide/cgroup-v2.html
    title: 'Linux kernel: Control Group v2 (the cpuset controller)'
  - id: switch-to-configuration
    resource: https://github.com/NixOS/nixpkgs/blob/3ec636362e1816bc2f0888fa0fa2c69f1bc9e504/pkgs/by-name/sw/switch-to-configuration-ng/src/main.rs
    title: 'nixpkgs switch-to-configuration-ng main.rs at the pinned revision (user manager re-exec)'
  - id: polkit-manual
    resource: https://www.freedesktop.org/software/polkit/docs/latest/polkit.8.html
    title: 'polkit(8): authorization rules, action.lookup()'
---

**Where:** [battlenet sub-flake](../packages/battlenet.md) (launcher, units and
module), [nebula-battlenet](../modules/nebula-battlenet.md) (the host's
`confineSlices = [ "app.slice" ]` and `confineNixDaemon = true`).

## Context

`cpus = "0-5,12-17"` pins the session to the 9900X3D's 3D V-Cache CCD, and
`WINE_CPU_TOPOLOGY` keeps WoW from widening it. That keeps the game on those
CPUs but not other work off them. `amd_x3d_mode = frequency` only makes the
scheduler prefer the other CCD. Builds are the heavy competitor. The
compilers of a cargo build are spawned by the long-lived sccache server,
which was started outside any one command, so no wrapper's affinity reaches
them, and Nix builds run under the system's `nix-daemon.service`.

On nebula, WoW started from the desktop entry ran in
`user@1000.service/session.slice/wayland-wm@hyprland.desktop.service` (uwsm,
Hyprland's exec). Ghostty terminals, Claude sessions, the sccache server and
the `wowdps-dev` service ran under `user@1000.service/app.slice`. The user
manager had `DelegateControllers=cpu memory pids` (upstream `user@.service`
says `Delegate=pids memory cpu`). The root cgroup offers `cpuset`, but
without delegation `systemctl --user set-property app.slice AllowedCPUs=…`
changed nothing.

## Decision

A cgroup cpuset on the cgroup the work lives in: the kernel holds every
process in it to its CPUs, however the process started.[^kernel-cgroup-v2]
The README has the user-facing account.[^subflake-readme]

- **Confine `app.slice` and `nix-daemon.service`, not everything.**
  `app.slice` holds the work that competes with the game: terminals and what
  runs in them, agent sessions, the sccache server and the user services.
  `session.slice` holds Hyprland and what it starts directly. That is light,
  and the game waits on the compositor's frames, so squeezing it onto the
  other CCD gains nothing. Of the system's units only `nix-daemon.service`
  does build work, and the rest belong to the system manager. Both are
  explicit host choices (`programs.battlenet.confineSlices`,
  `confineNixDaemon`). Each target is held to the online CPUs outside the
  sessions' (`AllowedCPUs=`).[^systemd-resource-control]
- **The game gets its own scope in `battlenet.slice`.** Started from a
  terminal, the game would otherwise be inside `app.slice`, and `taskset` to
  `0-5,12-17` inside a cpuset of `6-11,18-23` fails with EINVAL. Every
  invocation that starts Wine with a CPU list (the owner and every
  `runinprefix` join) runs the sandbox with
  `systemd-run --user --scope --slice=battlenet.slice`, a top-level user
  slice no confinement touches, wherever it was started from.[^systemd-run]
  In scope mode `systemd-run` registers its own PID as the scope, waits for
  the start job, then `execvpe`s the command in
  place,[^systemd-run-source] so the PID the owner waits on and `kill_tree`
  walks is unchanged. It runs with `--expand-environment=no`, because
  `systemd-run` expands `$VAR` in arguments by default, even in scope mode.
  The CPU list is probed in such a scope too, since from a confined terminal
  the cpuset would narrow the list or refuse it.
- **systemd decides when it ends, not the launcher.** The first version set
  `AllowedCPUs` from the owning launcher and cleared it from a bash EXIT
  trap. That broke three ways: a SIGKILL or the OOM killer skipped the trap
  and left `app.slice` confined, the first of two concurrent owners to exit
  cleared it for both, and `battlenet kill` cleared it whether or not a
  session still ran. Now each session scope has
  `Upholds=`/`Before=battlenet-confine@TARGET:CPUS.service`, a
  `StopWhenUnneeded=` oneshot.[^systemd-unit] systemd starts it with the
  first scope that upholds it and stops it after the last one ends, so the
  confinement lasts exactly as long as some session's Wine does, and nothing
  in the launcher has to survive for it to end. `Upholds=` rather than
  `Wants=`: under `Wants=`, a session started while the unit was still
  stopping after the previous one lost its start job to that stop and ran
  unconfined. `Upholds=` starts the unit again once the stop is done. Its
  `ExecStart=` and `ExecStopPost=` (which also runs after a failed start)
  both run `battlenet _confine`. Under a lock, that sets the target to the
  online CPUs outside the CPUs of every one of the target's units that is
  active or starting. A starting unit counts itself and a stopping one
  doesn't, so sessions with different CPU lists combine and the last stop
  clears. If systemd can't list the units, the target stays as it is. It
  clears rather than restoring an earlier value, because the launcher owns
  that property on its targets.
- **A user slice's delegation goes through `user@.service`.** A non-empty
  list sets `Delegate=pids memory cpu cpuset` in the NixOS drop-in for
  `user@.service` (the upstream list plus `cpuset`, in full, so it doesn't
  matter whether systemd adds a drop-in's list to the unit's or replaces it).
  The drop-in says `X-RestartIfChanged=false`, so a switch doesn't restart
  the user manager, but the switch does re-execute running user
  managers,[^switch-to-configuration] and that hands the controller over.
  systemd applies a slice's `AllowedCPUs` before it
  replies,[^systemd-dbus-slice] so one read of `cpuset.cpus.effective` right
  after `set-property` shows whether it took.
- **`nix-daemon.service` goes through a polkit-gated root oneshot.** A user
  can't set a system unit's properties. `battlenet-confine-nix@CPUS.service`
  runs as root and sets `nix-daemon.service`'s `AllowedCPUs` to `CPUS`
  (`none` clears it). A polkit rule lets members of `users` start only units
  matching `battlenet-confine-nix@([0-9_-]+|none).service`, by systemd's
  `unit` and `verb` details.[^polkit-manual] The script accepts only `none`
  or the online CPUs outside `cpus`, so the most a user can do with it is
  hold builds off the game's CPUs or let them back. A session on other CPUs
  (`BATTLENET_CPUS`) leaves the daemon as it is. This is narrower than
  letting users `set-property` the daemon, which would also let them set
  its memory and device limits. The daemon serves the whole machine, but
  each user's launcher counts only that user's sessions, which suits
  nebula's one player.
- **Confinement never fails a launch.** When `systemd-run` can't start a
  scope, or a target can't be set, the launcher or the unit says so in a
  notification and the journal, and the session runs without it.

## Consequences

The first version was checked before any live run, on 2026-10-26: the
module's assertions, the `user@.service` drop-in text, the CPU-list
complement, and the trap paths in a stubbed harness. It landed in commit
`16a6712`, and nebula switched to it that night. On 2026-10-27, after a
1 h 23 min session, `app.slice`'s `AllowedCPUs` was clear again and the game
had run in a `run-*.scope` under `battlenet.slice`. The user manager had
started before the switch and had only been re-executed by it, yet a test
scope with `AllowedCPUs` got cpuset files, so the switch's re-execution was
enough. The first version's advice to log in again was wrong.

The systemd-tracked version was tested live on 2026-10-27 with the built unit in
the runtime unit directory, a throwaway `bnettest.slice`, and a fake sandbox
in place of Wine. One session on `0-5,12-17` held the slice to `6-11,18-23`.
A second on `0-7` made it `8-11,18-23`, the first one's end made it `8-23`,
and the second's cleared it. A launcher killed with SIGKILL left the slice
confined until the fake game exited, then it cleared. A HUP with a closed
stderr stopped the sandbox and exited 130, where the old script exited 1
and left it running. `--help`, `kill` and unknown commands started no
scopes. The `nix-daemon.service` path failed cleanly ("interactive
authentication required") before the polkit rule existed. After the switch,
in a real session (2026-10-27): both units active,
`app.slice` and `nix-daemon.service` each with `cpuset.cpus.effective`
`6-11,18-23` (the polkit rule let the user unit start
`battlenet-confine-nix@6-11_18-23.service`), and the game's processes in a
`battlenet.slice` scope on `0-5,12-17`. Landed in commit `0e2090e`.

A second review's fixes were tested on 2026-10-28, while a real session ran,
with the unit and lock renamed (`bnettest-confine@`) and a 2 s pause in the
unit's stop. A session started during that stop got the unit back once the
stop was done, and its own end released it. A SIGTERM with stderr on a pipe
nobody read killed the old launcher with SIGPIPE (exit 141) and left the fake
sandbox running. The new one exits 130 and stops it. When `list-units`
fails, the target now stays as it is instead of being cleared. In a shell
held to `6-11,18-23` with no scope to escape to, `30-40` and `x` are now
called invalid instead of being blamed on the shell. With `systemctl`
stubbed, the root helper took `6-11_18-23` and `18-23_6-11` and refused
`8-11_18-23`, `0-23`, `0` and non-lists. A session on `0-7` left
`nix-daemon.service` alone. Landed in commit `43dc3d4`.

Known edges:

- A game started from the desktop entry no longer lives in Hyprland's
  service cgroup.
- Every Wine-starting invocation starts one short probe scope before the
  sandbox's own.
- Runtime properties (`set-property --runtime`) outlive their unit. If the
  user manager dies while a session runs, a target can stay confined until
  the next session ends or someone clears it by hand.
- Clearing writes an empty runtime `AllowedCPUs=`, which overrides a value
  the unit sets itself until reboot. The module refuses targets that NixOS
  configures with `AllowedCPUs`, but can't see `~/.config/systemd/user`.
- With two players on one machine, the first to stop releases
  `nix-daemon.service` for both.

[^kernel-cgroup-v2]: Linux kernel Control Group v2: the cpuset controller
[^subflake-readme]: `flakes/battlenet/README.md`: keeping other work off those CPUs
[^systemd-resource-control]: systemd.resource-control(5): `AllowedCPUs=`, `Delegate=`
[^systemd-unit]: systemd.unit(5): `StopWhenUnneeded=`, `Upholds=`, `Before=`
[^systemd-run]: systemd-run(1): `--scope`, `--slice=`, `--expand-environment=`
[^systemd-run-source]: systemd v262 `src/run/run.c`: `start_transient_scope()` (`pidref_set_self`, `execvpe`)
[^switch-to-configuration]: nixpkgs `switch-to-configuration-ng`: user activation calls `systemd.reexecute()`
[^systemd-dbus-slice]: systemd v262 `src/core/dbus-slice.c`: `bus_slice_commit_properties()` calls `unit_realize_cgroup()`
[^polkit-manual]: polkit(8): authorization rules and `action.lookup()`; systemd's `manage-units` action carries `unit` and `verb`
