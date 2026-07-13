---
type: Nix Package
title: okf
description: okf — CLI for maintaining OKF knowledge bundles (scaffold/index/validate/viz), consumed from its own repo via FlakeHub (kriswill/okflight).
tags: [package, flake-input, okf]
timestamp: '2026-07-05T00:00:00-07:00'
---

okf — CLI for maintaining OKF knowledge bundles (scaffold/index/validate/viz).

Lives in its own **public** repository,
[kriswill/okflight](https://github.com/kriswill/okflight), consumed as the
`okf` flake input from [FlakeHub](https://flakehub.com/flake/kriswill/okflight)
(`https://flakehub.com/f/kriswill/okflight/0` — tracks the 0.x release
series, so the pin only moves on published releases; the earlier plain
`github:` fetch and the pre-public git+ssh/1Password auth story are
historical) and re-exported as `packages.<system>.okf`
([packages](../modules/packages.md)); advance the pin with
`nix flake update okf`. History: `scripts/okf/` → `flakes/okf/`
([okf-subflake](../decisions/okf-subflake.md), 2026-07-04) → okflight via
`git subtree split`, all 18 okf commits preserved
([okflight-extraction](../decisions/okflight-extraction.md), 2026-07-05).

Consumption after the extraction:

- **Dev shell** ([dev](../modules/dev.md)) puts the **nix-built** CLI on
  `PATH`. Live-edit hacking moved to a checkout
  (`bun ~/src/okflight/okf.ts`, or `--override-input okf
  path:$HOME/src/okflight`); `viz --check`/`--perf` only work there — the
  packaged CLI's `node_modules` is a read-only store path.
- **`packages.<system>.okf`** runs from the store: sources + vendored
  `node_modules` (fixed-output `bun install` keyed on `bun.lock` — refresh
  procedure in okflight's README) + a `bun run --no-install` wrapper. The
  workspace it operates on is discovered from the caller's cwd (nearest
  `okflight.toml`, else the git toplevel), so the same binary serves any
  consuming repo.
- **GitHub Pages CI** (`.github/workflows/pages.yml`) builds `viz.html`
  bun-natively — no nix on CI — checking out okflight at the
  flake.lock-pinned rev via a read-only deploy key
  (`OKFLIGHT_DEPLOY_KEY` secret).

The store output deliberately excludes the test suite (`test/`,
`viz-app/*.test.ts`): bun's test scanner follows the `result` symlink that
`nix build` leaves in the flake root, so a shipped suite would run as a
stale second copy alongside a checkout's (`bun test` reported 24 files
instead of 12). `checks.<system>.test` builds from a separate full-tree
fileset with git in the sandbox, so the gitProvider tests (evil-merge
dating, auto-selection) run there instead of skipIf-skipping.

okf is generic (the [okf-toml-unified-config](../decisions/okf-toml-unified-config.md)
arc); this repo's scaffolding logic lives in
[`knowledge/_okflight/scripts/`](../_okflight/scripts/main.ts) — one pass file per
scaffolded type (`modules.ts`, `hosts.ts`, `packages.ts`, `nvim.ts`) behind
a `main.ts` entry — dynamically imported by `okf scaffold` per
`okflight.toml [scaffold] script` and driven through the injected
`ScaffoldContext` API
([okf-scaffold-hook](../decisions/okf-scaffold-hook.md),
[okf-scaffold-split](../decisions/okf-scaffold-split.md)). The passes'
type-only import is satisfied by the vendored
[`scaffold-api.d.ts`](../_okflight/scripts/scaffold-api.d.ts).

No `bun build --compile`: `okf viz` bundles the
[Svelte](../svelte-language.md) viewer with `Bun.build`
+ bun-plugin-svelte at CLI runtime, so the bun runtime and node_modules must
be present.

## Source

- Repository: [kriswill/okflight](https://github.com/kriswill/okflight) (public; released on [FlakeHub](https://flakehub.com/flake/kriswill/okflight))
- README: [okflight README](https://github.com/kriswill/okflight/blob/main/README.md)
- Re-export: [`modules/packages.nix`](../../modules/packages.nix)
