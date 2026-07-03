---
type: Darwin Module
title: Direnv
description: 'Kris'' direnv + nix-direnv.'
resource: modules/darwin/direnv.nix
tags: [darwin-module]
timestamp: '2026-06-28T18:27:01-07:00'
---

Kris' direnv + nix-direnv.

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/direnv.nix`](../../modules/darwin/direnv.nix)
- Stow package: [`home/direnv/`](../../home/direnv/) — see the [stow tree pattern](../patterns/stow-tree.md)
