---
type: Decision
title: Keep Long-Running User Oneshots Out of the Switch's Restart Set
description: 'User units that can sit in "activating" for a long time (debounced capture oneshots, a notification waiting on a click) set restartIfChanged = false — and the notifier is Type=exec — because switch-to-configuration-ng now restarts changed user units and blocks on those jobs before it restarts the system units it stopped.'
tags: [nixos, systemd, switch-to-configuration, nebula]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-24T15:45:00-07:00 }
sources:
  - id: stc-ng-source
    resource: https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/sw/switch-to-configuration-ng/src/main.rs
    title: switch-to-configuration-ng source (`do_user_switch`, `block_on_jobs`)
  - id: restart-if-changed-option
    resource: https://search.nixos.org/options?channel=unstable&query=systemd.user.services.%3Cname%3E.restartIfChanged
    title: '`systemd.user.services.<name>.restartIfChanged`'
---

**Where:** [herdr-update-check](../modules/herdr-update-check.md),
[users-k-helium](../modules/users-k-helium.md),
[users-k-noctalia](../modules/users-k-noctalia.md),
[git](../modules/git.md); felt through [nh](../modules/nh.md)'s `nrs`.

## Context

After the 2026-10-23 nixpkgs bump (`3ec6363`), `nrs` on
[nebula](../hosts/nebula.md) hung at nh's "Activating configuration" with no
further output. switch-to-configuration-ng had gained a user-scope pass:
for each logged-in user it plans stop/restart/start of the
`/etc/systemd/user` units that changed, like the system pass does, and runs
it synchronously with `block_on_jobs`. Only after that does the
system pass restart and start the system units it stopped before activation.[^stc-ng-source]
A unit counts as active when it is `active` **or `activating`**, so an
in-flight oneshot is stopped and then started again, and its start job only
completes when the new run exits.

`herdr-update-check.service` was a oneshot whose run ends with
`timeout 12h notify-send -A …`, so it stays `activating` until the
notification is clicked. Its unit changed in the bump (new store paths),
so the switch restarted it and then waited on the click. Ctrl-C left the
machine with NetworkManager, cups, avahi, upower, tor, opensnitchd,
timesyncd, lactd and openrgb **stopped**. It also left resume lists in
`/run/nixos/` and `/run/user/<uid>/nixos/`, which the next run replays, and
that re-queued the same start and hung the retry too. The path-triggered
capture oneshots (helium sleeps 30s, noctalia and gh 5s) have the same
shape on a smaller scale. A switch that lands mid-debounce waits out the sleep.

## Decision

- `herdr-update-check`: `serviceConfig.Type = "exec"` (its start job
  finishes as soon as the script execs; the unit is `active` while the
  notification is up) and `restartIfChanged = false` (a switch neither
  waits on it nor tears down and re-pops a pending notification).
  `TimeoutStartSec` went away with the oneshot. `timeout 12h` still bounds
  the run.
- `helium-config-capture`, `noctalia-config-capture`, `gh-config-capture`:
  `restartIfChanged = false`, which emits `X-RestartIfChanged=false`; the
  switch then lists them under "NOT restarting".[^restart-if-changed-option]
  An in-flight capture finishes on the old script; the next path trigger
  uses the new one.

## Consequences

- Rule for new user units: a oneshot that can stay `activating` for more
  than a moment (sleeps, network waits, waiting on the user) either sets
  `restartIfChanged = false` or is not a oneshot. Otherwise every switch that
  changes it can stall with system services down.
- Recovery after an interrupted switch: `systemctl --user list-jobs` shows
  the blocking job. Stop that unit, then re-run `nrs`, which replays the
  leftover lists and brings the stopped system units back.
- `flatpak-repo` (user, `RemainAfterExit`) is still restarted on change; its
  `ExecCondition` can wait up to ~30s for DNS when offline. That is accepted
  for now.

[^stc-ng-source]: switch-to-configuration-ng source (`do_user_switch`, `block_on_jobs`)
[^restart-if-changed-option]: `systemd.user.services.<name>.restartIfChanged`
