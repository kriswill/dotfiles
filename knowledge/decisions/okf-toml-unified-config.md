---
type: Decision
title: okf.toml — One Config File for Every okf Command
description: Rename okf-viz.toml to okf.toml and route ALL commands (scaffold/index/validate/viz) through one strict build-side loader (config-cli.ts), so bundle.dir and future CLI sections apply uniformly; first step of the okf generalization arc.
tags: [tooling, config, okf-generalization]
timestamp: '2026-07-04T00:00:00-07:00'
---

**Status:** active. **Where:**
[../../flakes/okf/config-cli.ts](../../flakes/okf/config-cli.ts) (loader),
[../../okf.toml](../../okf.toml) (this repo's config). Extends
[viz-config-toml](viz-config-toml.md).

## Context

[viz-config-toml](viz-config-toml.md) moved the viewer's repo-specifics into
`okf-viz.toml`, but only `okf viz` read it: `validate`/`index`/`scaffold`
still hardcoded `knowledge/` (`bundleRoot()`, a second literal in
validate.ts's repo-link resolution, index-gen's `# knowledge` root heading).
A repo configuring `bundle.dir` got a viz that worked and three commands
operating on a nonexistent directory. An audit (2026-07-04) of okf's
reusability made this the first blocker: one config, uniformly honored, is
the foundation every later generalization step (profile policy, VCS
providers, scaffold hooks) builds on.

## Decision

- **`okf-viz.toml` → `okf.toml`** (`git mv`; the old name loaded with a
  deprecation warning during the arc — support removed at arc completion,
  see [okf-generalization](okf-generalization.md)). The name change is
  semantic: it is no longer viz settings, it is the okf workspace config.
- **One build-side loader, `flakes/okf/config-cli.ts`**, exposing a cached
  `loadContext()` → `{ root, bundle, cfg }`. It parses the TOML, will consume
  CLI-only sections as they land (`[profile]`, `[vcs]`, `[scaffold]`,
  `[index]`), and delegates the viewer sections to the existing
  `normalizeVizConfig(strict)`. CLI sections never enter the `#data` embed,
  preserving config.ts's lenient-renormalize-own-output invariant and
  keeping the browser bundle free of schema it can't use.
- **Commands consume the loader at module top** (`const { root, bundle, cfg }
  = loadContext()`) rather than a `run(ctx)` signature — the planned
  `run(ctx)` conversion was dropped deliberately: the cached singleton gives
  identical decoupling with surgical diffs (no ~1100-line reindent of files
  scaffold.ts will replace anyway), and a future `okf init` must run
  *without* a loadable workspace, which module-top opt-in makes trivial.
- **Strictness is now uniform:** a malformed or misspelled config fails
  every command (exit 1 with the offending key path), where the non-viz
  commands previously ignored the file entirely. Absent file -> generic
  defaults, unchanged.

## Consequences

- `.github/workflows/pages.yml` trigger path updated `okf-viz.toml` →
  `okf.toml` in the same commit — a miss would silently stop config edits
  from redeploying the published graph.
- `bundle.dir` is now honored by all four commands; the root index heading
  and validate's repo-link base derive from it.
- Verified against the pre-change baseline: validate 155/0/0, scaffold
  0-written/100-skipped, viz summary byte-identical
  (145 nodes / 490 edges / 287 files / 63 dirs / 33 of 42 commit links),
  244 bun tests green, store-built okf (`nix run ./flakes/okf#okf`)
  behaves identically.
- The generalization arc continues: `[profile]` (validation policy),
  `[vcs]` (provider adapters, forge-agnostic commit links), facet
  `classify` providers, and `[scaffold]` hooks all land as sections of this
  file — recorded in their own decision records as they arrive.
