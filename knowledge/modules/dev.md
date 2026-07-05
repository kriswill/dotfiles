---
type: Flake-parts Module
title: Dev
description: Development shell (deadnix, statix, nixfmt-tree, just, okf) and formatter.
resource: modules/dev.nix
tags: [flake-parts]
timestamp: '2026-07-05T00:00:00-07:00'
---

Development shell and formatter. Besides the
[Nix-language](../nix-language.md) lint/format tools (deadnix, statix,
nixfmt-tree) and just, the shell puts **`okf`** on `PATH` — the nix-built
knowledge-bundle CLI from the okflight flake input
(`okf scaffold|index|validate|viz`, see the
[OKF Profile](../okf-profile.md)). Until the
[okflight extraction](../decisions/okflight-extraction.md) (2026-07-05) this
was an impure wrapper over the in-tree `flakes/okf/` working tree; live-edit
okf hacking now happens in a [checkout](../packages/okf.md) instead
(`bun ~/src/okflight/okf.ts`, or rebuild the shell with
`--override-input okf path:$HOME/src/okflight`).

Plumbing layer of the flake — see the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/dev.nix`](../../modules/dev.nix)
- Tooling: [kriswill/okflight](https://github.com/kriswill/okflight)
