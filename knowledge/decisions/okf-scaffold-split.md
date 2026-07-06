---
type: Decision
title: okf Scaffolder — Per-Type Passes, Bundle-Adjacent in knowledge/_okf-scaffold/
description: The repo's scaffold pass split from one 520-line monolith into a main.ts entry plus one pass file per scaffolded type, relocated from scripts/ to knowledge/_okf-scaffold/ — the `_` prefix hides it from okf's walkers, so the bundle stays pure markdown and OKF v0.1-conformant.
tags: [tooling, scaffold, okf]
timestamp: '2026-07-05T00:00:00-07:00'
---

**Status:** active. **Where:**
[../_okflight/scripts/main.ts](../_okflight/scripts/main.ts) (entry),
[../_okflight/scripts/lib.ts](../_okflight/scripts/lib.ts) (shared repo access +
class vocabulary). Follows on from
[okf-scaffold-hook](okf-scaffold-hook.md), which moved the pass out of the
okf flake in the first place.

## Context

The repo-owned scaffolder was a single 520-line file, one function covering
five unrelated scans (feature modules, plumbing modules, hosts + host files,
packages/overlays/sub-flakes, nvim plugins) — hard to navigate, and every
component-scan change meant editing the monolith. It also lived in
`scripts/` next to unrelated package-update helpers, though it is really
bundle tooling: it exists only to write `knowledge/` docs. The open question
was whether moving it under `knowledge/` would break OKF v0.1 conformance.

## Decision

- **One pass per scaffolded type**: `main.ts` default-exports the
  orchestrator; `modules.ts`, `hosts.ts`, `packages.ts`, `nvim.ts` each own
  one scan. `lib.ts` carries the shared `Repo` file-access helpers and the
  darwin/nixos class vocabulary. The directory name carries the okf-scaffold
  context, so the files inside don't repeat it. The only inter-pass coupling
  is explicit: the modules pass returns the module-name set, which the hosts
  pass takes as a parameter (enable-flag filter + doc-slug collision check).
- **Location `knowledge/_okf-scaffold/`**: the OKF v0.1 spec's conformance
  rules (SPEC §9) only govern `.md` files — it is silent on other files in
  the bundle tree, so scripts there don't invalidate the bundle. okf's own
  walkers (`walkMd`, index-gen) skip `_`-prefixed entries — the same
  exclusion convention import-tree uses in `modules/` — so validate, index,
  and viz never see the directory and the knowledge graph stays clean. A
  plain, un-prefixed directory was rejected: index-gen would list it as a
  bundle subdirectory and generate an `index.md` inside it.

## Consequences

- Component-scan changes now edit the one pass file that owns the scan;
  cross-pass plumbing changes surface in the entry's four-line call order.
- Parity-verified: a harness ran the old monolith (from git HEAD) and the
  new entry against the real repo with an identical fake `ScaffoldContext`
  capturing `emit()` output — 100 docs from each, byte-identical. The live
  `okf scaffold` run: 0 written, 100 skipped, unchanged.
- `okf.toml [scaffold] script` points at `knowledge/_okf-scaffold/main.ts`;
  `scripts/` is back to non-okf helpers only.
- Anything else added under `knowledge/_okf-scaffold/` inherits the
  exclusion — it will never appear in the graph, by design.

## Citations

- [OKF SPEC.md §9 (conformance)](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
- [okf-scaffold-hook](okf-scaffold-hook.md) — the prior move out of the flake
