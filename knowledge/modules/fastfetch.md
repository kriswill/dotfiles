---
type: Darwin Module
title: Fastfetch
description: 'Kris'' fastfetch.'
resource: modules/darwin/fastfetch.nix
tags: [darwin-module]
timestamp: '2026-06-11T16:31:03-07:00'
---

Kris' fastfetch.

Wraps the package (symlinkJoin + wrapProgram, the [diffnav](diffnav.md) idiom)
to pass `--logo` with `hexley-nix.png` from the stow tree (Hexley the
platypus on the Nix snowflake) — the darwin-only logo override. The shared
`config.jsonc` keeps `Nebula.png` as its `source` for nebula; CLI flags win
on macOS. Details: [`docs/fastfetch.md`](../../docs/fastfetch.md).

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/fastfetch.nix`](../../modules/darwin/fastfetch.nix)
- Stow package: [`home/fastfetch/`](../../home/fastfetch/) — see the [stow tree pattern](../patterns/stow-tree.md)
