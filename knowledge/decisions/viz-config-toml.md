---
type: Decision
title: Viz Config — Repo Specifics in a Root viz.toml
description: Move every dotfiles-specific string and setting out of the viz code into an optional repo-root viz.toml (strict-parsed at build, embedded normalized in the #data blob); without it okf viz builds a generic viewer with no platform filter, alphabetical types, and a flat legend.
tags: [viz, tooling, config]
timestamp: '2026-07-04T00:00:00-07:00'
---

**Status:** active. **Where:** [../../viz.toml](../../viz.toml), schema in
[../../scripts/okf/viz-app/config.ts](../../scripts/okf/viz-app/config.ts),
loaded by [../../scripts/okf/viz.ts](../../scripts/okf/viz.ts).

## Context

The viz tool hardcoded everything specific to this repository: the sidebar
header and help-bubble text, the darwin/nixos platform filter (the
`modules/packages.nix` path, its darwin/linux `optionalAttrs` guard parsing,
`NIXOS_HOSTS = {nebula}`, a type→OS rule table, the segment labels), the type
taxonomy (`TYPE_ORDER` palette slots, `GROUP_OF_DIR`, `GROUP_ORDER`), the
embed size cap, the `knowledge/` bundle-dir literal (including a magic
`slice(10, -3)` in markdown.ts), and the output filename. That blocked the
first step of generalizing the viewer so other projects can point it at
their own OKF bundles.

## Decision

All of it moves to an **optional `viz.toml` at the repo root** (exhaustive
scope, deliberate): `[bundle]` dir/out, `[display]` title/badge/
fallback-name/name/about-html, `[embed]` max-bytes, `[taxonomy]`
types/group-order/dir-groups/other, `[platform]`
values/types/hosts/host-default/packages-nix/nix-guards, `[repo]` url.

Mechanics, all in one shared module (`viz-app/config.ts`):

- **Strict at build, lenient in the app.** viz.ts parses the file with
  `Bun.TOML.parse` (zero new dependencies) and normalizes with
  `strict: true` — unknown keys, type mismatches, reserved platform names
  (`all`/`both`/`neutral`/`hosts`/`packages`), and dangling cross-references
  fail the build with the offending key path; silent misconfig is worse than
  a hard error. The **normalized** config rides the existing `#data` JSON
  blob; `buildModel` re-normalizes leniently (defaults-fill, never throws),
  which is also what gives test fixtures and config-less bundles a working
  viewer. Normalization accepts kebab-case (TOML) and camelCase (its own
  output), making it idempotent — a test enforces this.
- **Generic fallbacks without viz.toml:** no platform control (every concept
  "neutral", foreign `os=` hash params clamp to "all"), alphabetical types
  with generated colors, a flat legend without cluster headers, generic
  header ("OKF bundle") and about text. The dotfiles behavior now lives
  entirely in the checked-in viz.toml; the built output with it is
  functionally identical to before.
- **Stable palette slots over re-slotting:** `taxonomy.types` entry N maps to
  CSS var `--sN` (12 theme slots); overflow types get stable generated colors
  and >12 entries is a build warning, not an error — alphabetical slot
  assignment would repaint existing types whenever one is added.
- **`about-html` is trusted `{@html}`:** the config is single-author,
  checked-in repo content, same trust level as the code; the normalizer still
  type-checks it as a string.

Deliberately **left hardcoded**: the `LANG_BY_EXT`/`KEYWORDS` lexer maps
(language knowledge, not repo identity), localStorage keys
(`okfVizPanelW`/`okfVizTheme`), `window.__okf` and the `viz:` perf-mark
prefix, theme stop names, and the `/commit/` outbound-URL shape.

## Consequences

- Revises [viz-svelte-rebuild](viz-svelte-rebuild.md)'s "no config files
  beyond tsconfig/bunfig" stance: viz.toml is authored repo *content* the
  pipeline reads, not build-tool configuration; the one-shot `Bun.build` and
  single-file output are untouched.
- `parsePackagePlatforms` takes the guard map as an argument and only runs
  when `platform.packages-nix` is configured; `platformOf` is a config-driven
  rule table; the `Platform` type is a plain string.
- `.github/workflows/pages.yml` triggers on `viz.toml` changes so config
  edits redeploy the published graph.
- Follow-ups for true external consumption: `repoRoot()` is still
  script-relative (two levels up), and scaffold/index/validate still use the
  hardcoded `bundleRoot()`; both stay in-repo assumptions until a second
  consumer exists.
