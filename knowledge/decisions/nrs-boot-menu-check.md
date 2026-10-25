---
type: Decision
title: Skip the Boot Step Only When grub.cfg Says So
description: 'nrs skips setting the profile and rewriting GRUB for an unchanged build only after reading grub.cfg under the sudo it already holds and finding that the default entry boots the build and every listed generation still exists; an earlier user-local record plus a GC hook was rejected after code review.'
tags: [nrs, grub, bootloader, gc]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-24T19:30:00-07:00 }
sources:
  - id: nrs-pipeline
    resource: ../../docs/nrs-pipeline.html
    title: 'docs/nrs-pipeline.html: the nrs pipeline, design interrogation and proposals'
---

**Where:** [nrs](../modules/nrs.md) (`bootloader_current` in
`pkgs/nrs.sh`); context in [configuration](../modules/configuration.md).

## Context

nrs inherited nh's unconditional "set the profile, then
`switch-to-configuration boot`". For an unchanged build that adds no
generation, because re-setting a profile to the same path is a no-op (checked
on nebula). But it regenerates an identical `grub.cfg` and prints
"updating GRUB 2 menu...", which is wasted work that looks like change.

The obvious skip test, "the profile already points at this build", is unsafe.
The always-run step had a side effect: it rewrote the menu after a garbage
collection. GC deletes old generations but never touches `grub.cfg`, and
picking one of the dead entries at boot drops into emergency mode, as on
2026-06-16. `/boot` is root-only on nebula (`drwx------`).

## Decision

The first version (commit `0672a12`) skipped the step when the profile and a
user-local record (`~/.local/state/nrs2/bootloader`, from when it was named nrs2: the last store path nrs
wrote) both matched the build. To make up for the lost GC repair, it added an
`ExecStartPost` refresh to `nix-gc.service`. A code review found real holes:
- **Manual GC.** `nix-collect-garbage -d` or `nh clean` was not covered.
- **The record could disagree with GRUB.** It tracked only nrs's own
  writes. After another tool wrote the menu and the profile was rolled back,
  the record still matched and the step was wrongly skipped.
- **The hook ran only after a successful GC.** It was `ExecStartPost`.
- **The hook's `-` prefix swallowed every failure**, not just the lock clash
  it was meant for.
- **New lock clash.** The hook could take switch-to-configuration's lock
  during a user switch and make that switch fail.

The replacement reads the real state. nrs already holds sudo credentials
for activation, so it reads `/boot/grub/grub.cfg` and skips only when all
three hold:
- the profile is the build;
- the first `init=` (install-grub writes the default "NixOS" entry first,
  each with `init=<system>/init`) is the build;
- every `init=` the menu lists still exists in the store.

A missing, unreadable or unrecognised file means "rewrite", which is the safe
direction. The record and the GC hook are both removed. `--boot` still forces
a rewrite.

## Consequences

- **Self-repair after any GC.** Any `nrs` after a GC repairs the menu,
  whatever ran the GC, and so does a run after an interrupted switch or a
  rollback.
- **The gap left, closed 2026-10-24.** Between a GC and the next switch, GRUB
  could still list collected generations. P15 closed this without a GC
  hook: every bootloader install now GC-roots each system the menu lists
  ([Retain Generations by Boot History; Root What GRUB Lists](generation-retention.md)),
  so a listed generation can't be collected at all.[^nrs-pipeline] nrs's
  check stays, as a backstop for menus written before the roots existed.
- **A format dependency.** The check depends on install-grub's entry format
  (`init=` paths, default first). If that format changes, the check stops
  matching and nrs just rewrites every time: no worse than nh.

[^nrs-pipeline]: docs/nrs-pipeline.html: the nrs pipeline, design interrogation and proposals
