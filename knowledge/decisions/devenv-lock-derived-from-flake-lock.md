---
type: Decision
title: 'Derive a Project''s devenv.lock From Its flake.lock'
description: 'devenv-enabled flake projects pin devenv.yaml''s shared inputs to the exact revs flake.lock locks — a sync script re-derives devenv.lock, CI gates parity plus an enterTest contract, and the weekly update PR is opened with a repo-scoped GitHub App token.'
tags: [devenv, ci, locking]
generated: { by: okflight/0.4.0, at: 2026-08-02T16:23:53-07:00 }
sources:
  - id: flake-explorer-pr-131
    resource: https://github.com/kriswill/flake-explorer/pull/131
    title: 'flake-explorer PR #131'
  - id: peter-evans-create-pull-request-concepts-guideli
    resource: https://github.com/peter-evans/create-pull-request/blob/main/docs/concepts-guidelines.md
    title: peter-evans/create-pull-request — concepts & guidelines
  - id: actions-create-github-app-token
    resource: https://github.com/actions/create-github-app-token
    title: actions/create-github-app-token
---

**Status:** active. **Where:** [devenv](../modules/devenv.md); first consumer
[kriswill/flake-explorer](https://github.com/kriswill/flake-explorer) — the
reference implementation this record exists to make copyable.

## Context

devenv arrived via [the native-hook decision](devenv-native-hook-over-direnv.md);
pairing it with a project that already has a flake devShell creates a second
source of truth (`devenv.nix` twins the shell) and a second lock:
`devenv.yaml` tracks branches and `devenv.lock` resolves them independently
of `flake.lock`, so the two environments drift — different toolchains in
`nix develop` vs the devenv shell, cold caches in CI. Aligning the locks by
hand ("run both updates the same day") is approximate and unverifiable.
Separately, automating the weekly bump hits GitHub's recursion guard: PRs
created with the default `GITHUB_TOKEN` never trigger CI (that token is
itself the github-actions app's installation token; there is no opt-out),
and the standard PAT workaround expires and rides on a user account.

## Decision

`flake.lock` is canonical; `devenv.lock` is derived, never hand-updated:

- `scripts/sync-devenv-lock.ts` (bun) rewrites `devenv.yaml`'s shared inputs
  (nixpkgs, treefmt-nix) to `github:owner/repo/<rev>` pins read from
  `flake.lock`, runs `devenv update`, and asserts the two locks agree;
  `--check` asserts without touching anything. devenv.lock's own `devenv`
  node (cachix/devenv's module tree) has no flake counterpart and floats.
- `devenv.nix` carries an `enterTest` contract — every promised tool
  resolves, pinned versions match, env vars point at executables. CI's
  `devenv` job runs the parity check first, then `devenv test` with the CLI
  taken from the flake-locked nixpkgs rev, sharing the store paths the other
  nix jobs already cache (the job runs in ~2–3 min).
- A weekly `update-locks` workflow runs `nix flake update`, re-derives the
  pins, and opens one PR carrying all three lock artifacts, authenticated by
  a repo-scoped GitHub App (`actions/create-github-app-token`): the
  installation token lives an hour, is revoked when the job ends, and the
  bot-authored PR triggers CI like any human push.

## Consequences

- Toolchain parity between `nix develop`, the devenv shell, and CI is
  enforced, not hoped for — a bare `devenv update` cannot merge (the parity
  gate catches it), which is why devenv.yaml carries a "don't hand-edit"
  header.
- The GitHub App needs one-time manual setup per repo (create + install,
  client-id variable, private-key secret) but never expires, unlike a
  fine-grained PAT's annual rotation, and its PRs author as the app bot.
- No-diff weeks open no PR (verified by a `workflow_dispatch` rehearsal).
