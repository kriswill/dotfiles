---
type: NixOS Module
title: Wowdps Journal Backup
description: 'Hourly check for the wowdps-suite coordinator journal backup: a declarative copy of the suite''s tools/journal-backup.{service,timer} (~/src/wowdps-suite, install notes in tools/journal-backup.md).'
resource: modules/hosts/nebula/wowdps-journal-backup.nix
tags: [nixos-module, host-specific]
generated: { by: okflight/0.5.0, at: 2026-11-24T02:35:19+00:00 }
---

Hourly check for the wowdps-suite coordinator journal backup: a declarative copy of the suite's tools/journal-backup.{service,timer} (~/src/wowdps-suite, install notes in tools/journal-backup.md). The suite's own 20-hour `--if-due` window decides whether a run actually snapshots; the saved plan (local rotation under ~/.local/state/wowdps-suite/journal-backups, mirror to /mnt/nas/wowdps-journal — nas-mount.nix) was set up once with `--save`. Exit 3 = local snapshot done, NAS mirror skipped (the log says why); the timer retries just the mirror on the next tick. ConditionUser=k: the units point at k's checkout and dev shell. The NAS automount is a system unit, so no ordering here — the first access mounts it.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/wowdps-journal-backup.nix`](../../modules/hosts/nebula/wowdps-journal-backup.nix)
