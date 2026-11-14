---
type: Decision
title: codebase-memory-mcp via Nix-aware Fork
description: 'The codebase-memory MCP server is consumed from the kriswill fork''s nix branch (Nix symbols + flake topology, PR #19 upstream) with its index artifact kept out of git for now.'
resource: modules/darwin/codebase-memory-mcp.nix
tags: [mcp, codebase-memory, fork]
generated: { by: codex/gpt-6, at: 2026-11-13T23:52:00-08:00 }
sources:
  - id: kriswill-codebase-memory-mcp-pr-19
    resource: https://github.com/kriswill/codebase-memory-mcp
    title: 'kriswill/codebase-memory-mcp PR #19'
---

**Status:** active. **Where:**
[codebase-memory-mcp](../modules/codebase-memory-mcp.md).

## Current deployment

As of 2026-11-13, all host installations and the repository MCP launch entry
are disabled at the user's request to remove startup/indexing work. The
flake input, module re-exports, overlay and package outputs stay available.
Existing indexes are preserved. This changes deployment, not the choice of
fork. K's generation-289 launch interval was 40.656 seconds, but it ran in
parallel with other startup work. The [generation-290 comparison](../../docs/shell-startup-performance.md#k-follow-up-comparison-generation-290-2026-11-14)
did not establish an equal whole-boot saving.

## Context

Upstream codebase-memory-mcp had no Nix language support, so the code graph
was blind to this repo's primary language.

## Decision

- Consume `github:kriswill/codebase-memory-mcp/nix` — the fork adds Nix
  symbol extraction and flake-topology passes (submitted upstream as PR #19);
  rebase the fork onto upstream when bumping.
- The fork's darwin module exposes `services.codebase-memory-mcp.{enable,package}`
  (renamed from `kriswill.codebase-memory.*`; tracked in `b64c2ca`); fork
  commit `1d99463` added the NixOS twin (`nixosModules.codebase-memory-mcp`,
  systemd user service) and made `cbm-tools` cross-platform.
- The index is persisted in-repo at `.codebase-memory/graph.db.zst`
  (bootstrap: delete project + reindex with `persistence: true`; refresh via
  the watcher) but the path is **gitignored for now** (`2f22430`) while the
  churn/value trade-off is evaluated.

## Consequences

- Graph queries understand modules, options, and flake wiring.
- Input bumps may require fork rebases before picking up upstream fixes.
- The gitignore call is provisional — revisit once the artifact's diff noise
  is understood.

## Citations

- Commits `b64c2ca`, `2f22430`
