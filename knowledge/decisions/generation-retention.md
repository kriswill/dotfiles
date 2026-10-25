---
type: Decision
title: Retain Generations by Boot History; Root What GRUB Lists
description: 'The system profile keeps the systems that actually booted successfully (current boot, two before it, the last other kernel) plus the boot default and the previous good switch, read from the journal; other profiles keep the old 7-day rule; and every bootloader install GC-roots what the GRUB menu lists. This replaces age-only GC, and the GC-triggered GRUB refresh rejected in review.'
tags: [nixos, gc, grub, generations, nebula]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-24T22:10:00-07:00 }
sources:
  - id: nrs-pipeline
    resource: ../../docs/nrs-pipeline.html
    title: 'docs/nrs-pipeline.html: the nrs pipeline, design interrogation and proposals'
  - id: nix-env-delete-generations
    resource: https://nix.dev/manual/nix/latest/command-ref/nix-env/delete-generations
    title: nix-env --delete-generations
---

**Where:** [generations](../modules/generations.md). Proposal P15 in the
pipeline report.[^nrs-pipeline] It follows
[Skip the Boot Step Only When grub.cfg Says So](nrs-boot-menu-check.md),
whose open gap it closes.

## Context

Two problems, one cause each:
- **GRUB listing collected generations.** `grub.cfg` is written only by a
  switch or boot, but GC deletes generations whenever it runs. An older menu
  entry whose closure was collected drops the boot into emergency mode, as on
  2026-06-16. A GC-triggered menu refresh was tried and rejected in review:
  - it missed manual GC;
  - it ran only after a successful GC;
  - its `-` prefix swallowed failures;
  - it could take switch-to-configuration's non-blocking lock and make a
    user's switch fail.
- **Age-only retention.** snowglobe's nightly
  `nix-collect-garbage --delete-older-than 7d` keeps a week of switches but
  not what matters for recovery. On 2026-10-24 the generation behind every
  earlier boot, kernel 7.2.10's included, was gone, while seven
  switched-but-never-booted generations from the last two days were kept. A
  generation that activated may still fail to boot. That was the June
  `exit 0` activation bug, for example.

## Decision

- **Root the menu.** `grub-menu-roots` runs from
  `boot.loader.grub.extraInstallCommands`, right after `install-grub.pl`.
  It swaps in `/nix/var/nix/gcroots/grub-menu/`, holding one root per store
  path an entry's `init=` names. Because the protection is a GC root, it
  covers every collector. It runs inside stc's own bootloader step, so it
  needs no extra lock, and `set -e` makes a failure visible.
- **Retain the system profile by boot history.** The user's proposal: the
  current boot, the previous two successful boots, and the previous kernel
  version's boot. Added to it:
  - the boot default and the running system (nix-env would refuse to delete
    them anyway);
  - **the previous good switch**, the runtime counterpart of a successful
    boot, so a switch that broke something at runtime can still be undone.
    Most generations are switched to and never booted. This is the newest
    system, other than the running system and the boot default, that
    switch-to-configuration logged `finished switching to system
    configuration …` for (`-t nixos`). stc logs that only when activation
    exits 0 with every unit started; a failure logs `… failed (status N)`.
    The journal held 66 such records back to 2026-08-13. A generation that
    was only set with `boot`, or whose activation failed, never qualifies.
    Without any record, the newest earlier generation with a system
    different from the default's is kept instead. This was first "the
    generation numbered just before the default", and was refined the same
    day to require evidence, like the boot rule.

  The previous boots are distinct systems that still have a generation,
  newest first, other than the current boot's. The kernel fallback is the
  newest such system with a different kernel **semver**. Only
  `MAJOR.MINOR.PATCH` of the modules directory counts, so a rebuild of the
  same version (gen 155's 7.3.0 against the booted 7.3.0) or a
  `-zen1`/`-rc1` suffix is not a different kernel. This is the user's call:
  version, not build.
- **Boot history from the journal.** The journal is persistent on nebula,
  with 12 boots back to 2026-08-10. A boot's system is the `init=` on its
  `Command line:` kernel message. "Successful" means systemd logged
  `MESSAGE_ID=b07a249cd024414a82dd00cd181378ff` ("Startup finished"),
  which a boot stuck in emergency mode never reaches. This needs no new
  state, and it already holds the history. If the journal can't be read,
  the system profile is not pruned at all.
- **Other profiles keep the old rule** (`nix-env --delete-generations 7d`),
  and `nix-gc` becomes collect-only behind the prune step.
- **nh clean rejected.** In nh 4.4.2, `cleanable_generations` deletes
  generation links itself by count and age, with no exemption for the current
  generation. After a rollback it can delete the generation the profile
  points at. nix-env refuses that ("cannot delete current version of
  profile", checked).[^nix-env-delete-generations]

## Consequences

- The GRUB menu shrinks to what is kept: about 4–5 entries, each either
  boot-proven or the default and its predecessor.
- **Root directory access: `root:root 0755`, never writable by others.**
  These reasons come from Nix's source (`gc.cc`, `local-store.cc`,
  `daemon.cc`, checked 2026-10-24):
  - **Write must stay root-only.** Whoever can delete a root can let GC take
    a menu entry, which is the June failure. Adding roots would only let
    users pin paths, which the daemon already allows through `gcroots/auto`.
  - **World-read hides nothing.** The daemon's `FindRoots` censors only
    runtime and temp roots for untrusted clients, so `nix-store --gc
    --print-roots` already shows these links to any user. The world-readable
    `profiles/system-*-link` show the same store paths.
  - **0700 has a latent failure mode.** `findRoots` treats
    `permission_denied` as "cannot read potential root" and skips the
    directory. Its roots would then silently not count for any collector
    that isn't root. In multi-user mode GC always runs as root through the
    daemon, so it works today, but 0755 doesn't depend on that.
  - **Symlink modes don't matter on Linux**, and the directory isn't sticky,
    so `fs.protected_symlinks` doesn't apply.
  - **`/boot` is 0700 for a different reason.** The ESP is mounted with
    `fmask/dmask=0077`, and that need doesn't carry over to the roots.
- **Any directory under `gcroots` counts as roots**, because `findRoots`
  recurses into every subdirectory. So a temp set left by an interrupted run
  would pin its closures forever. `grub-menu-roots` therefore uses no temp
  directory, and removes the temp sets of earlier versions.
- **Roots are announced, not just linked.** A plain `ln -s` root, which the
  manual documents, isn't seen by a GC that is already running. `nix-store
  --add-root` (`IndirectRootStore::addPermRoot`) first calls `addTempRoot`,
  which hands the path to a running collector through its socket, then
  links it and records a back-pointer in `gcroots/auto`. The case it
  closes: a midnight `nix-gc` prunes a generation between `install-grub.pl`
  listing it and its root landing. Because of the back-pointers, the set is
  updated in place, adding first and then removing what the menu dropped,
  not swapped as a directory, which would leave every back-pointer
  dangling. A dropped entry's back-pointer goes stale and the next GC
  removes it ("removing stale link").
- A pruned generation stays in the menu, and bootable, until the next switch
  rewrites the menu. Its closure is freed by the GC after that, so disk is
  freed one switch late.
- Journal vacuuming shortens the known boot history. The kept set then falls
  back to the current boot, the default and the previous generation, never to
  nothing.
- **Tests:**
  - **Fake systems and a scripted history:** the previous boots and the
    kernel fallback are picked correctly, including when they coincide, a
    repeat boot of the current system is skipped, and an unreadable journal
    leaves the profile alone.
  - **The 7-day rule:** checked with real nix-env on backdated scratch
    profiles, including a rolled-back one.
  - **`grub-menu-roots`:** checked on synthetic menus, including the
    replacement and an empty menu.

[^nrs-pipeline]: docs/nrs-pipeline.html: the nrs pipeline, design interrogation and proposals
[^nix-env-delete-generations]: nix-env --delete-generations
