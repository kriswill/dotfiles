---
type: Flake-parts Module
title: Dev
description: Development shell (deadnix, statix, nixfmt-tree, just, okf) and formatter.
resource: modules/dev.nix
tags: [flake-parts]
timestamp: '2026-07-02T00:00:00-07:00'
---

Development shell and formatter. Besides the
[Nix-language](../nix-language.md) lint/format tools (deadnix, statix,
nixfmt-tree) and just, the shell puts **`okf`** on `PATH` — a
`writeShellApplication` wrapper (carrying its own [bun](../bun-runtime.md))
over the knowledge-bundle tooling
(`okf scaffold|index|validate|viz`, see the
[OKF Profile](../okf-profile.md)). The wrapper resolves the checkout at call
time via `git rev-parse --show-toplevel` and runs the **working tree** copy of
[`flakes/okf/`](../packages/okf.md) — edits are live, no rebuild. The
nix-built package from that sub-flake is for external consumption; see the
[okf-subflake](../decisions/okf-subflake.md) decision for the split.

Plumbing layer of the flake — see the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/dev.nix`](../../modules/dev.nix)
- Tooling: [`flakes/okf/`](../../flakes/okf/)
