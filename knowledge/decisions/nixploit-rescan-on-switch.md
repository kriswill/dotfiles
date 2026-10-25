---
type: Decision
title: Rescan on Switch Through the Timer's Unit File
description: 'services.nixploit.rescanOnSwitch makes a switch that changes the installed packages rescan by adding a hash of them to nixploit.timer as X-Packages, because switch-to-configuration restarts a timer whose unit file changed and upstream''s OnActiveSec=2min then fires; activation-script restart lists (deprecated) and a path unit on /run/current-system were rejected.'
tags: [nixploit, systemd, switch-to-configuration]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-25T13:30:00-07:00 }
sources:
  - id: nixploit-module
    resource: https://github.com/manic-systems/nixploit/blob/master/nix/module.nix
    title: 'nixploit NixOS module source (the timer, X-Job, OnActiveSec)'
  - id: stc-ng
    resource: https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/sw/switch-to-configuration-ng/src/main.rs
    title: 'switch-to-configuration-ng source (compare_units, handle_modified_unit, the activation restart list)'
  - id: systemd-timer
    resource: https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html
    title: 'systemd.timer(5): OnActiveSec=, RandomizedDelaySec='
  - id: timer-c
    resource: https://github.com/systemd/systemd/blob/v262/src/core/timer.c
    title: 'systemd v262 timer.c (timer_enter_waiting: one-time triggers, add_random_delay)'
---

**Where:** [nixploit sub-flake](../packages/nixploit.md)
(`flakes/nixploit/nixos-module.nix`), enabled by
[nebula-nixploit](../modules/nebula-nixploit.md).

## Context

nixploit scans the running system on a daily timer. After an `nrs` that
removed Lutris, the report kept listing the ffmpeg 6.1.6 that only Lutris
pulled in, until the next calendar run. Upstream already rescans after some
switches: the timer carries the job config's store path as `X-Job` and has
`OnActiveSec=2min`.[^nixploit-module] switch-to-configuration compares unit
files, ignores only a fixed list of `[Unit]` keys (`Description`,
`X-Reload-Triggers` and a few more), and restarts a changed timer.[^stc-ng]
The restarted timer fires after `OnActiveSec` plus upstream's
`RandomizedDelaySec=15min`, which systemd adds to monotonic triggers too, so
2 to 17 minutes later.[^systemd-timer] So changing the settings rescans, but
changing the packages doesn't.

## Decision

`rescanOnSwitch` adds `X-Packages` to `nixploit.timer`. Its value is
`builtins.hashString "sha256"` over `config.system.path` and every
`users.users.<name>.packages`. It is a hash because the value only has to
change, and the user package list could be long. The toplevel itself can't
be the key, since the timer unit is part of the toplevel (infinite
recursion).

Rejected:

- **Activation script writing `/run/nixos/activation-restart-list`.** It
  would catch every switch, but switch-to-configuration-ng warns that it's
  deprecated and due for removal in NixOS 26.11.[^stc-ng] An activation
  script also runs during boot activation, where nebula has been bitten
  before.
- **A path unit on `/run/current-system`.** systemd fires `PathChanged=` only
  for events on the watched path's own watch. That watch follows the symlink
  into a read-only store directory, and the swap of the link shows up only on
  the parent directory's watch.
- **Restarting the scan from `nrs`.** That would tie a cross-platform helper
  to one NixOS service, and switches made without nrs would miss it.

## Consequences

A switch that adds or drops a system or user package rescans 2 to 17 minutes
later. A run takes 1 to 3 minutes with warm feeds (2026-10-25). Changes
outside those packages still wait for the daily run: a service's own
`package` option, `etc` content, firmware. Kernel changes are already
covered, because the Kbuild tree is part of the job config. A no-op switch
doesn't rescan.

A manual `systemctl start nixploit` while the rescan is pending cancels it.
When that run ends, systemd re-arms the timer, finds the one-time
`OnActiveSec` point already past, and disables it.[^timer-c] That's harmless,
since the manual run scanned the new system. On 2026-10-25 the first switch
with the key restarted the timer at 12:22:56. A manual start at 12:24:49 ran
the scan, and the timer never fired.

[^nixploit-module]: nixploit NixOS module source (the timer, X-Job, OnActiveSec)
[^stc-ng]: switch-to-configuration-ng source (compare_units, handle_modified_unit, the activation restart list)
[^systemd-timer]: systemd.timer(5): OnActiveSec=, RandomizedDelaySec=
[^timer-c]: systemd v262 timer.c (timer_enter_waiting: one-time triggers, add_random_delay)
