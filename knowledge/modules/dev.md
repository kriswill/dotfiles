---
type: Flake-parts Module
title: Dev
description: Development shell (deadnix, statix, nixfmt-tree, just, okf) and formatter.
resource: modules/dev.nix
tags: [flake-parts]
timestamp: '2026-07-02T00:00:00-07:00'
---

Development shell and formatter. Besides the lint/format tools (deadnix,
statix, nixfmt-tree, just), the shell puts **`okf`** on `PATH` — a
`writeShellApplication` wrapper over the knowledge-bundle tooling
(`okf scaffold|index|validate|viz`, see the
[OKF Profile](../okf-profile.md)). The wrapper resolves the checkout at call
time via `git rev-parse --show-toplevel` rather than baking a store copy of
`scripts/okf/` in, because the tools read and write the working tree.

Plumbing layer of the flake — see the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/dev.nix`](../../modules/dev.nix)
- Tooling: [`scripts/okf/`](../../scripts/okf/)
