---
type: Decision
title: okf Scaffold Hooks — Repo-Owned Script plus Declarative Collect Tier
description: okf scaffold becomes a generic driver — the metadata pass belongs to the repo, wired via okf.toml [scaffold] as a dynamically-imported script receiving an injected ScaffoldContext API, and/or declarative [[scaffold.collect]] glob+template entries; the 566-line dotfiles scaffolder moved out of the flake to scripts/okf-scaffold.ts.
tags: [tooling, okf-generalization, scaffold]
timestamp: '2026-07-04T00:00:00-07:00'
---

**Status:** active. **Where:**
[`scaffold-api.ts`](https://github.com/kriswill/okflight/blob/main/scaffold-api.ts)
(injected API), [`scaffold.ts`](https://github.com/kriswill/okflight/blob/main/scaffold.ts)
(generic driver), [../_okf-scaffold/main.ts](../_okf-scaffold/main.ts)
(this repo's pass — since split per type and moved bundle-adjacent, see
[okf-scaffold-split](okf-scaffold-split.md)). Part of the okf generalization
arc ([okf-toml-unified-config](okf-toml-unified-config.md)).

## Context

`okf scaffold` was 566 lines of this repository's architecture in code form:
darwin/nixos module classes and twin merging, enable-gating regexes, host
class detection, pkgs/overlays/flakes scans, the nvim plugin tree, and
hardcoded cross-links into hand-authored pattern/playbook docs. No config
DSL can express that honestly — the metadata pass is inherently per-repo —
but a generic okf still owes repos the harness: idempotent emission,
frontmatter serialization, VCS timestamps, comment extraction.

## Decision

Three tiers, all wired in `okf.toml [scaffold]`:

- **`script`** — a workspace-relative module okf dynamically imports; its
  default export receives a `ScaffoldContext`. The API is
  **context-injected**: `emit` (owns idempotence, `--force`, mkdir,
  logging, the written/skipped counters), `timestamp` (VCS-backed, the old
  gitISO contract), `leadingComment(src, marker)` with configurable
  markers, sentence/description/slug/yaml helpers, plus `root`/`bundle`/
  `config`/`vcs`/`force`. The script imports **types only** from okf (bun
  erases type imports) plus node/bun builtins — no runtime import from the
  okf checkout, so a vendored, cloned, or /nix/store okf all work, and the
  script survives okf's future extraction to its own repository.
- **`command`** — the non-JS escape hatch: any argv spawned at the
  workspace root with `OKF_ROOT`/`OKF_BUNDLE`/`OKF_BUNDLE_DIR`/`OKF_FORCE`
  env; it owns its own writes. Mutually exclusive with `script`.
- **`[[scaffold.collect]]`** — declarative entries for simple repos: `glob`
  (matched against the VCS provider's tracked files) + `type` + `output`
  template + optional `comment` marker (leading-comment description
  extraction), `description`/`title`/`body` templates, `tags`, extra
  templated `frontmatter`. Placeholders (`{path} {name} {Title} {dir}
  {timestamp} {repo} {description} {description-sentence}`) are validated
  at config load — a typo is a config error, not a silently-literal brace.
  Runs after the imperative tier, so the script wins output collisions
  (emit skips existing paths).

The dotfiles pass moved to `scripts/okf-scaffold.ts` (AGENTS.md's home for
repo helper scripts; keeps `knowledge/` pure markdown) as a **mechanical
port** — same emit calls, same strings.

## Consequences

- **Parity-verified:** old vs new `scaffold --force` output diffed
  byte-identical across two scratch worktrees, modulo the pre-existing
  now()-fallback timestamps on four merge-added packages (`git log
  --name-only` omits merge commits — known quirk, tracked separately).
  Normal runs: `0 written, 100 skipped`, unchanged.
- The store-built okf (`nix run ./flakes/okf#okf -- scaffold`) imports the
  repo-side script by absolute path from the target workspace — verified.
- Repo scaffold scripts must stick to the injected API + builtins (no own
  node_modules — the store okf has no install step for them).
- `okf scaffold` with nothing configured prints guidance and exits 0, so a
  fresh bundle without hooks isn't an error.
- Component-scan changes (new source dirs, doc types, cross-links) are now
  edits to the repo-side pass (today `knowledge/_okf-scaffold/`, per
  [okf-scaffold-split](okf-scaffold-split.md)), not to the flake —
  flakes/okf/ has no dotfiles knowledge left in its scaffold path.
