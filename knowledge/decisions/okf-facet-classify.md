---
type: Decision
title: Facet Classify Providers — nix-optional-attrs and command
description: Generalize the facet build-side source from the Nix-only nix-packages table to a tagged classify union — the built-in nix-optional-attrs parser or an arbitrary command printing a JSON name->value map — so non-Nix repos can classify concepts by anything.
tags: [viz, tooling, config, okf-generalization]
timestamp: '2026-07-04T00:00:00-07:00'
---

**Status:** active. **Where:** schema in
[`viz-app/config.ts`](https://github.com/kriswill/okflight/blob/main/viz-app/config.ts)
(`FacetClassify`), build execution in
[`viz.ts`](https://github.com/kriswill/okflight/blob/main/viz.ts), resolution in
[`viz-app/data.ts`](https://github.com/kriswill/okflight/blob/main/viz-app/data.ts). Part of
the okf generalization arc
([okf-toml-unified-config](okf-toml-unified-config.md)).

## Context

The facet mechanism ([viz-config-toml](viz-config-toml.md)) was generic
except for one leak: the build-side source was literally named
`nix-packages` and could only ever parse `lib.optionalAttrs` guards out of a
Nix file. A Python monorepo classifying services by team, or a docs repo
classifying pages by audience, had no way in.

## Decision

`[facet.<name>.classify]` is a tagged union selected by `provider`:

- **`nix-optional-attrs`** — the existing parser, unchanged and still
  built-in (`parsePackagePlatforms` stays in data.ts with its test suite; a
  Nix-aware battery included in a generic tool costs non-Nix users nothing).
  Keys: `file`, `guards`.
- **`command`** — any argv, run at the workspace root at viz build time,
  printing a JSON object of string values on stdout. Non-zero exit, invalid
  JSON, non-string values, or values outside the facet's declared `values`
  **fail the build** (strict-config philosophy — silent misclassification is
  worse than an error). The script is repo-owned content, same trust domain
  as the repo's CI workflow.

Shared keys: `types` (which concept types consult the map) and `key =
"basename" | "id"` (how map keys match concepts; basename is the historical
behavior). The legacy `[facet.<name>.nix-packages]` spelling still
normalizes to the nix-optional-attrs variant — old embeds and copied
configs keep working; canonical output is `classify`, and re-normalization
is idempotent (tested).

The viewer runtime is unchanged in shape: it consumes only the embedded
`facetMaps`, so the page stays browser-safe — no provider code ships in
viz.html.

## Consequences

- This repo's okf.toml moved to the `classify` spelling in the same commit;
  the platform facet map is byte-identical to the pre-change baseline
  (5 entries) and the resolution precedence
  (ids -> classify -> frontmatter -> types) is untouched.
- The Pages CI runner executes repo-configured classify commands during the
  viz build — acceptable: the config and scripts are repo content, already
  the workflow's trust domain.
- `key = "id"` unlocks classifiers for bundles whose concept basenames
  collide across directories.
