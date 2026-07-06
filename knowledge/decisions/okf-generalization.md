---
type: Decision
title: okf Generalization Arc — Complete
description: The eight-step arc that turned okf from a dotfiles-specific tool into a generic OKF knowledge-bundle CLI — one okf.toml for all commands, configurable profile policy, VCS provider adapters (git + none), forge-agnostic links, classify providers, repo-owned scaffold hooks, okf init — finished extraction-ready in-tree; verified by a three-way second-repo smoke test.
tags: [tooling, okf-generalization]
timestamp: '2026-07-04T00:00:00-07:00'
---

**Status:** complete (2026-07-04). **Umbrella over:**
[okf-toml-unified-config](okf-toml-unified-config.md) ·
[okf-vcs-provider](okf-vcs-provider.md) ·
[okf-facet-classify](okf-facet-classify.md) ·
[okf-scaffold-hook](okf-scaffold-hook.md).

## Context

An audit (2026-07-04) found okf entangled with this repository six ways:
hardcoded `knowledge/` in three of four commands, validation policy in
code, a 566-line dotfiles-specific scaffolder inside the flake, a Nix-only
facet source, GitHub-only links with git as a hard requirement, and
repo-specific help text. Goal: any project — any language or domain, no
Nix, eventually no VCS — can adopt an OKF bundle with this tool.

## Decision (what shipped, in step order)

1. **okf.toml** (renamed from okf-viz.toml), one strict loader
   (`config-cli.ts`) for all commands; `bundle.dir` honored everywhere.
2. **`[profile]`** — required/recommended fields, reserved files,
   link policies; defaults reproduce the old hardcoded behavior.
3. **`VcsProvider`** adapters + forge-agnostic `commit-url-template`;
   lib.ts reduced to pure text helpers.
4. **`none` provider** (fs walk + mtime + ignore globs) and config-first
   root discovery (nearest okf.toml, else git toplevel) — okf runs with no
   VCS and no git binary at all.
5. **Facet `classify` union** — built-in `nix-optional-attrs` or any
   `command` printing a JSON map.
6. **Scaffold hooks** — the dotfiles pass moved to
   `scripts/okf-scaffold.ts` (parity-diffed byte-identical), driven by the
   injected `ScaffoldContext` API; declarative `[[scaffold.collect]]` tier
   for simple repos; `command` escape hatch.
7. **Config-aware help** + **`okf init`** bootstrapper.
8. **Extraction sweep** — flake source free of dotfiles assumptions
   (remaining by design: package.nix homepage TODO + maintainer, the
   generic `knowledge` default, Nix-flavored provider docs); test fixtures
   neutralized; the okf-viz.toml legacy fallback removed.

Deliberately in-tree: extraction to a standalone repo stays a one-line
input-URL swap per the [sub-flake pattern](../patterns/subflake-extraction.md).

## Consequences

- **Acceptance (three-way second-repo smoke):** a fresh non-Nix Python
  repo — (A) git provider: init → collect-tier scaffold (leading-comment
  descriptions, real commit timestamps) → index → validate 0/0 → viz;
  (B) `.git` deleted: identical results on the none provider, scaffold
  idempotent; (C) okf copied out of this repo, `bun install`, driving the
  same workspace with no Nix and no git anywhere.
- This repo's behavior is unchanged throughout: validate 0-error/0-warn at
  every step, scaffold 0-written/100-skipped, viz commit links 33/42 and
  the platform facet map (5 entries) byte-stable, 285 bun tests, the store
  package green including its git-less sandbox test check.
- ~~Merge-added files fall back to now() timestamps in the git provider.~~
  Closed same day: `--diff-merges=c` on the batched date pass (see
  [okf-vcs-provider](okf-vcs-provider.md)) — `scaffold --force` is now
  fully deterministic.
- Remaining known gap: the syntax-highlighter language table is small
  (unknown extensions degrade to plain text gracefully).
