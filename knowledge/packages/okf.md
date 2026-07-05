---
type: Sub-flake
title: okf
description: okf — CLI for maintaining OKF knowledge bundles (scaffold/index/validate/viz).
resource: flakes/okf/
tags: [sub-flake, package]
timestamp: '2026-07-04T23:17:27+00:00'
---

okf — CLI for maintaining OKF knowledge bundles (scaffold/index/validate/viz).

Consumed by the root flake as a relative-path input — see the
[sub-flake extraction pattern](../patterns/subflake-extraction.md). Lived at
`scripts/okf/` until the [okf-subflake](../decisions/okf-subflake.md) move
(2026-07-04). Two consumption modes, deliberately split:

- **Dev shell** ([dev](../modules/dev.md)) wraps the **working tree** via
  [bun](../bun-runtime.md) — edits are live, no rebuild;
  `viz --check`/`--perf` only work here.
- **`packages.<system>.okf`** runs from the store: sources + vendored
  `node_modules` (fixed-output `bun install` keyed on `bun.lock` — refresh
  procedure in the README) + a `bun run --no-install` wrapper. The repo it
  operates on is resolved from the caller's cwd (`git rev-parse
  --show-toplevel`), so the same binary serves any consuming repo.

No `bun build --compile`: `okf viz` bundles the Svelte viewer with `Bun.build`
+ bun-plugin-svelte at CLI runtime, so the bun runtime and node_modules must be
present. The GitHub Pages workflow (`.github/workflows/pages.yml`) builds
`viz.html` bun-natively from this tree — no nix on CI.

## Source

- Flake: [`flakes/okf/`](../../flakes/okf/)
- README: [`flakes/okf/README.md`](../../flakes/okf/README.md)
