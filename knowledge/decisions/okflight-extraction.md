---
type: Decision
title: Extract okf to Its Own Repository (okflight)
description: Promote flakes/okf to the private github:kriswill/okflight repo via git subtree split — the input-URL swap the sub-flake pattern promised — trading live working-tree edits for a pinned, independently-versioned dependency.
tags: [okf, sub-flake, extraction, okflight]
timestamp: '2026-07-05T00:00:00-07:00'
---

**Status:** active. **Where:** [okf](../packages/okf.md),
[dev](../modules/dev.md), `flake.nix` (`okf` input),
`.github/workflows/pages.yml`.

## Context

okf was always headed out of this repo
([okf-subflake](okf-subflake.md) staged it under `flakes/okf/` for exactly
this): it is generic (any repo, any VCS, own `okf.toml`), and keeping it
in-tree tied its release cadence to dotfiles commits. The
[sub-flake extraction pattern](../patterns/subflake-extraction.md) promised
that promotion would be a one-line input-URL swap.

## Decision

Create **`github:kriswill/okflight`** (private for now) and swap
`inputs.okf.url` from `"./flakes/okf"` to `"github:kriswill/okflight"` —
input name, `follows`, and all consumers unchanged, as the pattern promised.

- **Name** — *okflight* parses three ways at once: *OK-flight* (flying
  around the 3D viz), *OKF-light* (the glow-sphere starlight), *OKF-flight*.
  Chosen over star-themed candidates (staratlas = existing web3 brand;
  glowatlas, knowloom also free) after a GitHub exact-name availability
  sweep found zero collisions.
- **History** — `git subtree split --prefix=flakes/okf` rewrote the 18
  commits touching the path into a standalone lineage pushed as okflight's
  `main`; blame and archaeology survive the move.
- **Dev shell** — the impure working-tree wrapper is gone; `okf` on PATH is
  now the store build from the input. Live-edit hacking:
  `bun ~/src/okflight/okf.ts` or `--override-input okf
  path:$HOME/src/okflight`. Consequence: `viz --check`/`--perf` need a
  checkout (store `node_modules` is read-only).
- **Scaffold passes** — `knowledge/_okf-scaffold/` kept its type-only
  `ScaffoldContext` import via a vendored `okf-scaffold-api.d.ts`; the
  runtime API was already injected by `okf scaffold`, so nothing else moved.
- **Pages CI** — the workflow checks out okflight **at the
  flake.lock-pinned rev** (read via `jq` from `flake.lock`) using a
  read-only deploy key (`OKFLIGHT_DEPLOY_KEY` secret), so the published
  graph is always built by the okf this repo pins, not okflight HEAD.
  Trigger path `flakes/okf/**` became `flake.lock`.

## Consequences

- okf gains its own issues/PRs/releases and can be consumed by other repos;
  okf bumps here become explicit `nix flake update okf` lock changes.
- **Private-repo tax** until it goes public: every nix consumer needs
  `access-tokens = github.com=<token>` in `nix.conf` (this Mac: done, via
  `gh auth token`; **nebula needs the same** before its next rebuild —
  root's nix config, since `sudo nixos-rebuild` evaluates as root), and
  public clones of this repo cannot evaluate the flake (the lock references
  a repo they can't fetch). Going public erases both costs; consumers
  change nothing.
- The dotfiles dev shell no longer self-hosts okf development — the
  fast-iteration loop moved to the okflight checkout with its own dev shell
  and test suite.
