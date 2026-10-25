---
type: NixOS Module
title: Store Optimise
description: 'Store deduplication off the build path (report P13): auto-optimise-store off, a weekly persistent nix-store --optimise timer instead, early Sunday after the nightly nix-gc.'
resource: modules/nixos/store-optimise.nix
tags: [nixos-module]
generated: { by: claude-code/opus-5.5, at: 2026-10-24T22:55:00-07:00 }
---

Report proposal P13 (`docs/nrs-pipeline.html`). snowglobe sets
`auto-optimise-store = true` as a `setDefault`, which a plain assignment
outranks. With it on, every file a build or substitution writes is hashed
and hard-linked into `/nix/store/.links` as it lands, on the critical path
of every `nrs`.

The module turns it off and enables `nix.optimise` instead:
`nix-store --optimise` on `Sun 04:00`, with up to 30 min of random delay.
It is persistent, so a run missed while off happens at the next boot. That
is after Sunday's nightly [generations](generations.md) GC at 00:00, so it
doesn't hash files the GC is about to delete. A run only hashes what's new:
`loadInodeHash` reads every inode already in `.links`, and those files are
skipped. The disk saving is the same, just later.

The gain hasn't been measured. Time a large update before and after.
Nebula only: the Macs' Determinate Nix already has `auto-optimise-store =
false`, and nix-darwin doesn't manage Nix there.

Mounted ungated on every NixOS host
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/store-optimise.nix`](../../modules/nixos/store-optimise.nix)
