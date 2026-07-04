---
type: Decision
title: Viz Config — Repo Specifics in a Root okf-viz.toml
description: Move every dotfiles-specific string and setting out of the viz code into an optional repo-root okf-viz.toml (strict-parsed at build, embedded normalized in the #data blob); without it okf viz builds a generic viewer with no facet filters, alphabetical types, and a flat legend.
tags: [viz, tooling, config]
timestamp: '2026-07-04T00:00:00-07:00'
---

**Status:** active. **Where:** [../../okf-viz.toml](../../okf-viz.toml), schema in
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

All of it moves to an **optional `okf-viz.toml` at the repo root** (exhaustive
scope, deliberate): `[bundle]` dir/out, `[display]` title/badge/
fallback-name/name/about-html, `[embed]` max-bytes, `[taxonomy]`
types/group-order/dir-groups/other, 0..n `[facet.<name>]` filter lenses,
`[repo]` url.

Mechanics, all in one shared module (`viz-app/config.ts`):

- **Facets are a generic 0..n filter-lens mechanism, not a hardcoded platform
  axis.** Each `[facet.<name>]` table declares one independent segmented
  control: `values` (ordered segments after "all"; omitted — inferred from
  observed resolutions across all concepts, alpha-sorted), `types` (concept
  type -> value), `ids` (full concept id -> value, highest precedence),
  `frontmatter` (a doc frontmatter key read as a string value), and an
  opt-in `nix-packages` source (`file` + `guards` + the `types` it classifies
  by basename, via the same `optionalAttrs`-guard parse the old hardcoded
  platform filter used). **Resolution per concept, first hit wins:**
  `ids[id]` -> the `nix-packages` map (only for listed types; a miss falls
  through, it does not resolve) -> a `frontmatter` string value (an explicit
  `values` list makes an out-of-range value **unresolved with no
  fall-through** — the author explicitly tagged it, a typo shouldn't silently
  inherit the type default) -> `types[type]` -> **unresolved**, which is
  always visible for that facet regardless of the active selection.
  Visibility is AND across every active facet. This replaces the old
  `both`/`neutral` sentinels outright — they behaved identically to
  "unresolved" at runtime, so simply not listing a type now does what setting
  it to `"both"` used to.
- **Facet names are also hash-param names:** `^[a-z][a-z0-9-]*$`, unique, and
  none of `hide`/`q`/`isolate`/`os`/`all` (collision with the other query
  params or the "all" sentinel). A **legacy alias**: `?os=<value>` still
  decodes for a facet literally named `platform` when `platform=` itself is
  absent (dotfiles' only facet, so far, is `platform`) — encode never emits
  `os=` again, and App never rewrites the hash on load, so a previously
  published `?os=` link keeps resolving; only the next interaction re-encodes
  it canonically as `platform=`.
- **Strict at build, lenient in the app.** viz.ts parses the file with
  `Bun.TOML.parse` (zero new dependencies) and normalizes with
  `strict: true` — unknown keys, type mismatches, and dangling
  cross-references (a `types`/`ids`/`nix-packages.guards` value outside an
  explicit `values` list) fail the build with the offending key path; a
  rule-less facet that still declares `values` (a no-op lens) only warns.
  Silent misconfig is worse than a hard error. A `frontmatter`-tagged concept
  whose value falls outside an explicit `values` list is a **build warning**
  too, not a config error — `buildModel` (where resolution actually runs) is
  app-side and never throws or warns, so that check has to live in viz.ts,
  scanning the parsed concept frontmatter directly. The **normalized** config
  rides the existing `#data` JSON blob; `buildModel` re-normalizes leniently
  (defaults-fill, never throws), which is also what gives test fixtures and
  config-less bundles a working viewer. Normalization accepts the TOML
  `facet` table-of-tables (name-keyed) AND its own `facets` array output —
  mutually exclusive, and idempotent under a JSON round-trip (a test enforces
  this, including every facet field with nested nulls).
- **Generic fallbacks without okf-viz.toml:** no facet controls at all
  (nothing configured to hide by), alphabetical types with generated colors,
  a flat legend without cluster headers, generic header ("OKF bundle") and
  about text. The dotfiles behavior now lives entirely in the checked-in
  okf-viz.toml; the built output with it is functionally identical to
  before.
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
  beyond tsconfig/bunfig" stance: okf-viz.toml is authored repo *content* the
  pipeline reads, not build-tool configuration; the one-shot `Bun.build` and
  single-file output are untouched.
- `parsePackagePlatforms` is unchanged and now generic: it takes a guard map
  as an argument and only runs per facet that opts into a `nix-packages`
  source; `facetValueOf` is the config-driven resolution pipeline replacing
  the old type-only `platformOf` — facet values are plain strings, nothing
  reserved.
- `.github/workflows/pages.yml` triggers on `okf-viz.toml` changes so config
  edits redeploy the published graph.
- Follow-ups for true external consumption: `repoRoot()` is still
  script-relative (two levels up), and scaffold/index/validate still use the
  hardcoded `bundleRoot()`; both stay in-repo assumptions until a second
  consumer exists.
