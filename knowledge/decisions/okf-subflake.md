---
type: Decision
title: Extract okf into a Sub-flake
description: Move scripts/okf to flakes/okf with a real package output (vendored bun deps), keeping the impure dev-shell wrapper for fast iteration.
tags: [sub-flake, okf, bun]
timestamp: '2026-07-04T23:20:00+00:00'
---

**Status:** active. **Where:** [okf](../packages/okf.md),
[dev](../modules/dev.md), [`flakes/okf/`](../../flakes/okf/).

## Context

okf is headed toward full generalization — eventually its own repository,
consumed by many projects as a flake input. It lived at `scripts/okf/` as a
bun/TypeScript tree with two consumers that must not regress: the dev-shell
wrapper (working-tree execution, edits live without a rebuild) and the GitHub
Pages workflow (bun-native `viz` build, no nix on CI). A sub-flake is the
repo's stepping stone for exactly this ([sub-flake
extraction](../patterns/subflake-extraction.md)): later promotion is a one-line
input-URL swap.

## Decision

`git mv scripts/okf flakes/okf` plus a flake that exposes a **real package**,
not just moved files:

- **Packaging** — no bun helper exists in nixpkgs, and `bun build --compile`
  is impossible (`okf viz` runs `Bun.build` + bun-plugin-svelte at CLI
  runtime), so `package.nix` ships sources + vendored `node_modules` under
  `$out/lib/okf` with a `bun run --prefer-offline --no-install` wrapper —
  the fixed-output `bun install` pattern nixpkgs itself uses for
  opencode/helix-gpt. The lock is pure JS (no os/cpu-conditional deps), so one
  FOD hash serves all three systems. Not `--production`: viz needs
  devDependencies (svelte, bun-plugin-svelte) at runtime.
- **cwd-based repo resolution** — `lib.ts` `repoRoot()` switched from
  `import.meta.dir/../..` to `git rev-parse --show-toplevel` from the working
  directory, so the store-run binary operates on whatever repo it's invoked
  in. This is the only generalization taken now; the bundle dir stays
  hardcoded `knowledge/` and scaffold stays dotfiles-shaped by design.
- **Fast iteration preserved** — the dev shell keeps its impure
  working-tree wrapper (path repointed); the nix package is for external
  consumption and parity. The Pages workflow stays bun-native with paths
  updated.
- Root wiring follows the house pattern: relative-path input with
  nixpkgs/flake-parts `follows`, perSystem re-export +
  `flake.packages.aarch64-linux` block in `modules/packages.nix`. No overlay —
  no host installs okf system-wide.

## Consequences

- `nix run` / flake-input consumption works from any repo; spin-out is a URL
  swap away.
- The FOD hash must be refreshed when `bun.lock` changes or a nixpkgs bump
  changes bun's install layout (loud hash-mismatch failure; procedure in
  [`flakes/okf/README.md`](../../flakes/okf/README.md)).
- `okf viz --check` / `--perf` are dev-tree-only: svelte-check writes into
  `node_modules` (read-only in the store) and `--perf` needs local Chrome.
- The sub-flake's `checks.<system>.test` runs the 238 viewer tests offline
  against the vendored deps; the root's `nix flake check` does not include
  them — run `nix flake check ./flakes/okf` explicitly.

## Citations

- Commit `4e0b5bc` — the move, sub-flake, root wiring, and reference sweep
