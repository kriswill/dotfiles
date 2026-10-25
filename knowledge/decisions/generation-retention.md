---
type: Decision
title: Retain Generations by Boot History; Root What GRUB Lists
description: 'The system profile keeps the systems that actually booted successfully (current boot, two before it, the last other kernel) plus the boot default and its predecessor, read from the journal; other profiles keep the old 7-day rule; and every bootloader install GC-roots what the GRUB menu lists. This replaces age-only GC, and the GC-triggered GRUB refresh rejected in review.'
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
[Skip the Boot Step Only When grub.cfg Says So](nrs2-boot-menu-check.md),
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
  - **the generation before the boot default**, so `--rollback`'s one-step
    undo of a switch that broke something at runtime still works. Most
    generations are switched to and never booted.

  The previous boots are distinct systems that still have a generation,
  newest first, other than the current boot's. The kernel fallback is the
  newest such system on a different kernel version.
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
