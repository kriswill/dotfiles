---
type: NixOS Module
title: Generations
description: 'Generation retention by boot history, and GC roots for every system the GRUB menu lists: the nightly nix-gc only collects garbage, its preStart keeps the systems that booted successfully plus the boot default and the previous good switch, and each bootloader install roots the menu so no GC can strand a menu entry.'
resource: modules/nixos/generations.nix
tags: [nixos-module]
generated: { by: claude-code/opus-5.5, at: 2026-10-24T22:10:00-07:00 }
sources:
  - id: nrs-pipeline
    resource: ../../docs/nrs-pipeline.html
    title: 'docs/nrs-pipeline.html: the nrs manual (its §10 maps F1–F12 and P1–P17)'
---

Report proposal P15, done another way than the report sketched.[^nrs-pipeline]
The rationale, and the alternatives turned down, are in
[Retain Generations by Boot History; Root What GRUB Lists](../decisions/generation-retention.md).
The module has two parts.

**Retention** (`prune-generations.sh`, run as `nix-gc.service`'s
`preStart`). snowglobe's `nix.gc.options = "--delete-older-than 7d"` becomes
`""`, so `nix-collect-garbage` only collects. Pruning happens first.
- **The system profile** keeps the generations whose system is:
  - the current boot;
  - one of the previous `prevBoots` (2) distinct systems that booted
    successfully;
  - the newest successfully booted system on a different kernel semver.
    Only `MAJOR.MINOR.PATCH` counts, so a rebuild of the same version or a
    `-zen1`/`-rc1` suffix does not;
  - the boot default or the running system;
  - the **previous good switch**: the newest other system that
    switch-to-configuration logged `finished switching to system
    configuration …` for. It logs that only when activation exits 0 with
    every unit started. Without such a record, the newest earlier generation
    with a different system is kept instead.

  Boot and switch history come from the persistent journal. Each boot's
  system is the `init=` on its kernel command line. A boot counts as
  successful when systemd logged "Startup finished"
  (`MESSAGE_ID=b07a249c…`). Switches are stc's syslog lines (`-t nixos`). An
  unreadable journal leaves the profile untouched.
- **Every other profile** under `/nix/var/nix/profiles` and root's
  `~/.local/state/nix/profiles` keeps the old rule:
  `nix-env --delete-generations 7d`.
- All deletion goes through nix-env, which refuses to delete a current
  generation. A failure fails the unit before anything is collected.
- **Preview:** `prune-generations --dry 2 7 /nix/var/nix/profiles` (installed,
  no root needed for the system profile). On 2026-10-24, after gen 166, it
  would have kept four generations and deleted the eight switched-only ones:
  - 155, the previous boot;
  - 161, the current boot;
  - 165, the previous good switch;
  - 166, the default and running system.

**Menu roots** (`grub-menu-roots.sh`, from
`boot.loader.grub.extraInstallCommands`). Right after `install-grub.pl`
writes the menu, it replaces `/nix/var/nix/gcroots/grub-menu/` with one
root per system the menu boots (the store path of each entry's `init=`).
- **Any GC is safe:** no collection can take a closure the menu lists, so
  picking an older entry can't strand the boot in emergency mode
  (2026-06-16, see [nebula](../hosts/nebula.md)). That holds for the timer,
  a manual `nix-collect-garbage -d` and `nh clean` alike.
- **Roots follow the menu:** a pruned generation stays bootable from the
  current menu until the next switch rewrites it. Its closure is collected
  only after that.
- **No lock, and failures show:** it runs inside switch-to-configuration's
  own bootloader step, so it takes no lock of its own, and a failure fails
  that step visibly.
- **An unrecognized menu** (no `init=`) keeps the previous roots instead of
  failing the install.
- **Access:** `root:root 0755`, with root-owned symlinks; an explicit `chmod`
  means the umask can't change it. That is Nix's own convention: `gcroots`,
  `gcroots/auto` and both `per-user` dirs, the latter chmodded to 0755 by
  `local-store.cc` itself. The reasons are in the
  [decision](../decisions/generation-retention.md). The first deploy made it
  0700 (`mktemp -d`); corrected 2026-10-24.
- **Updated in place:** the script adds before it removes. Each root goes in
  through `nix-store --add-root`, which announces it to a GC already running
  before linking it, and leaves a back-pointer in `gcroots/auto`. Then the
  links the menu dropped are deleted. The set never holds fewer roots than
  either menu needs. With no temp directory, nothing can be left behind, and
  earlier versions' temp sets are removed on the next run.

Auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md);
ungated on every NixOS host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)).

## Source

- Module: [`modules/nixos/generations.nix`](../../modules/nixos/generations.nix)
- Scripts: [`prune-generations.sh`](../../modules/nixos/prune-generations.sh),
  [`grub-menu-roots.sh`](../../modules/nixos/grub-menu-roots.sh)

[^nrs-pipeline]: docs/nrs-pipeline.html: the nrs manual (its §10 maps F1–F12 and P1–P17)
