---
type: Decision
title: Confine app.slice While Battle.net Runs
description: 'While a Battle.net session runs, the battlenet launcher holds app.slice to the CPUs outside the game''s with a cgroup cpuset and runs the game in its own battlenet.slice scope, because affinity can''t reach work started elsewhere (the sccache server''s compilers); cpuset is delegated to user@.service for it, and restoring means clearing AllowedCPUs.'
tags: [battlenet, systemd, cgroups, cpu]
generated: { by: claude-code/opus-5.5, at: 2026-10-26T22:45:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/battlenet/README.md
    title: 'flakes/battlenet/README.md (keeping other work off those CPUs)'
  - id: systemd-resource-control
    resource: https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
    title: 'systemd.resource-control(5): AllowedCPUs=, Delegate='
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
---

**Where:** [battlenet sub-flake](../packages/battlenet.md) (launcher and
module), [nebula-battlenet](../modules/nebula-battlenet.md) (the host's
`confineSlices = [ "app.slice" ]`).

## Context

`cpus = "0-5,12-17"` pins the session to the 9900X3D's 3D V-Cache CCD, and
`WINE_CPU_TOPOLOGY` keeps WoW from widening it. That keeps the game on those
CPUs but not other work off them. `amd_x3d_mode = frequency` only makes the
scheduler prefer the other CCD. Builds are the heavy competitor, and the
compilers of a cargo build are spawned by the long-lived sccache server, which
was started outside any one command, so no wrapper's affinity reaches them.

On nebula, WoW started from the desktop entry ran in
`user@1000.service/session.slice/wayland-wm@hyprland.desktop.service` (uwsm,
Hyprland's exec). Ghostty terminals, Claude sessions, the sccache server and
the `wowdps-dev` service ran under `user@1000.service/app.slice`. The user
manager had `DelegateControllers=cpu memory pids` (upstream `user@.service`
says `Delegate=pids memory cpu`). The root cgroup offers `cpuset`, but
without delegation `systemctl --user set-property app.slice AllowedCPUs=…`
changed nothing.

## Decision

A cgroup cpuset on the slice the work lives in: the kernel holds every
process in it to the slice's CPUs, however the process started.[^kernel-cgroup-v2]
The README has the user-facing account.[^subflake-readme]

- **Confine `app.slice`, not everything.** `app.slice` holds the work that
  competes with the game: terminals and what runs in them, agent sessions,
  the sccache server and the user services. `session.slice` holds Hyprland
  and what it starts directly. That is light, and the game waits on the
  compositor's frames, so squeezing it onto the other CCD gains nothing.
  System slices belong to the system manager, which a user's launcher has
  no business changing. The option is a list per host
  (`programs.battlenet.confineSlices`), so what to confine stays an
  explicit host decision. The launcher holds each slice to the online CPUs
  outside the session's (`systemctl --user set-property --runtime`,
  `AllowedCPUs=`).[^systemd-resource-control]
- **The game gets its own scope in `battlenet.slice`.** Started from a
  terminal, the game would otherwise be inside `app.slice`, and `taskset` to
  `0-5,12-17` inside a cpuset of `6-11,18-23` fails with EINVAL. Every
  invocation that starts Wine (the owner and every `runinprefix` join) runs
  the sandbox with `systemd-run --user --scope --slice=battlenet.slice`, a
  top-level user slice no confinement touches, wherever it was started
  from.[^systemd-run] In scope mode `systemd-run` registers its own PID as
  the scope, waits for the start job, then `execvpe`s the command in
  place,[^systemd-run-source] so the PID the owner waits on and `kill_tree`
  walks is unchanged. It runs with `--expand-environment=no`, because
  `systemd-run` expands `$VAR` in arguments by default, even in scope mode.
  The CPU list is probed in such a scope too: from a confined terminal the
  cpuset would narrow the list or refuse it.
- **Restoring means clearing.** The EXIT trap sets `AllowedCPUs=` (empty)
  rather than putting back an earlier value: the launcher owns that property
  on those slices. Remembering a previous value would need state that
  survives a killed owner. Clearing needs none, it is idempotent, and it
  is what `battlenet kill` can do after an owner died to SIGKILL. The trap
  covers a normal end, `stop_session`'s `exit 130` (Ctrl-C, SIGTERM, a
  closed terminal) and a `set -e` failure. Its commands ignore errors,
  because a failing command in a bash EXIT trap under `set -e` ends the trap
  early and replaces the exit status.
- **Delegation goes through `user@.service`, and can wait for the next
  login.** A non-empty list sets `Delegate=pids memory cpu cpuset` in the
  NixOS drop-in for `user@.service` (the upstream list plus `cpuset`, in
  full, so it doesn't matter whether systemd adds a drop-in's list to the
  unit's or replaces it). The drop-in also says `X-RestartIfChanged=false`,
  so a switch doesn't restart the user manager, and a user manager learns
  its controllers when it starts. A switch does reload the system manager,
  which re-realizes every unit's cgroup, and re-executes running user
  managers,[^switch-to-configuration] so the delegation may already arrive
  then. That is untested, and the next login is the sure point. Meanwhile
  the launcher reads the slice's `cpuset.cpus.effective`; with no cpuset
  files it says confinement isn't active yet and goes on. systemd applies
  a slice's `AllowedCPUs` before it replies,[^systemd-dbus-slice] so one
  read right after `set-property` is enough.
- **Confinement never fails a launch.** Without a reachable user manager,
  or when `systemd-run` can't start a scope, the launcher says so once and
  runs as before: no scope, no confinement.

## Consequences

Checked before any live run, on 2026-10-26: the module's assertions (`cpus`
required, `battlenet.slice` refused), the `user@.service` drop-in text, the
CPU-list complement (`0-23` minus `0-5,12-17` is `6-11,18-23`; minus
everything is empty), and the trap paths in a stubbed harness (release once
after a normal end, after a `set -e` failure, and after INT, TERM and HUP,
with exit statuses 0, 1 and 130).

Still to see live, after the rebuild, possibly a new login, and a game
launch: `app.slice`'s `cpuset.cpus.effective` reading `6-11,18-23` during a
session and the full set after it, and WoW in a `run-*.scope` under
`battlenet.slice`.

Known edges:

- A join run with `BATTLENET_CONFINE=` (empty) from a terminal while a
  confined session runs gets no scope. Its CPU-list probe then fails with
  EINVAL inside the confined slice, and it stops at "Invalid CPU list".
- Two sessions on different prefixes share the confinement, and the first
  to end clears it for both.
- A game started from the desktop entry no longer lives in Hyprland's
  service cgroup.
- Every Wine-starting invocation now starts one short probe scope before
  the sandbox's own.

[^kernel-cgroup-v2]: Linux kernel Control Group v2: the cpuset controller
[^subflake-readme]: `flakes/battlenet/README.md`: keeping other work off those CPUs
[^systemd-resource-control]: systemd.resource-control(5): `AllowedCPUs=`, `Delegate=`
[^systemd-run]: systemd-run(1): `--scope`, `--slice=`, `--expand-environment=`
[^systemd-run-source]: systemd v262 `src/run/run.c`: `start_transient_scope()` (`pidref_set_self`, `execvpe`)
[^switch-to-configuration]: nixpkgs `switch-to-configuration-ng`: user activation calls `systemd.reexecute()`
[^systemd-dbus-slice]: systemd v262 `src/core/dbus-slice.c`: `bus_slice_commit_properties()` calls `unit_realize_cgroup()`
