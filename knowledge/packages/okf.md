---
type: Sub-flake
title: okf
description: okf — CLI for maintaining OKF knowledge bundles (scaffold/index/validate/viz).
resource: flakes/okf/
tags: [sub-flake, package]
timestamp: '2026-07-05T06:34:41+00:00'
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
  procedure in the README) + a `bun run --no-install` wrapper. The workspace
  it operates on is discovered from the caller's cwd (nearest `okf.toml`,
  else the git toplevel), so the same binary serves any consuming repo.

The store output deliberately excludes the test suite (`test/`,
`viz-app/*.test.ts`): bun's test scanner follows the `result` symlink that
`nix build` leaves in the flake root, so a shipped suite would run as a
stale second copy alongside the working tree's (`bun test` reported 24
files instead of 12). `checks.<system>.test` builds from a separate
full-tree fileset with git in the sandbox, so the gitProvider tests
(evil-merge dating, auto-selection) run there instead of skipIf-skipping.

okf is generic (the [okf-toml-unified-config](../decisions/okf-toml-unified-config.md)
arc); this repo's scaffolding logic lives outside the flake in
[`knowledge/_okf-scaffold/`](../_okf-scaffold/main.ts) — one pass file per
scaffolded type (`modules.ts`, `hosts.ts`, `packages.ts`, `nvim.ts`) behind
a `main.ts` entry — dynamically imported by `okf scaffold` per
`okf.toml [scaffold] script` and driven through the injected
`ScaffoldContext` API
([okf-scaffold-hook](../decisions/okf-scaffold-hook.md),
[okf-scaffold-split](../decisions/okf-scaffold-split.md)).

No `bun build --compile`: `okf viz` bundles the
[Svelte](../svelte-language.md) viewer with `Bun.build`
+ bun-plugin-svelte at CLI runtime, so the bun runtime and node_modules must be
present. The GitHub Pages workflow (`.github/workflows/pages.yml`) builds
`viz.html` bun-natively from this tree — no nix on CI.

## Source

- Flake: [`flakes/okf/`](../../flakes/okf/)
- README: [`flakes/okf/README.md`](../../flakes/okf/README.md)
