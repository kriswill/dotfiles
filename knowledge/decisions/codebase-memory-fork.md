---
type: Decision
title: codebase-memory-mcp via Nix-aware Fork
description: The codebase-memory MCP server is consumed from the kriswill fork's nix branch (Nix symbols + flake topology, PR #19 upstream) with its index artifact kept out of git for now.
resource: modules/darwin/codebase-memory-mcp.nix
tags: [mcp, codebase-memory, fork]
timestamp: '2026-07-02T00:00:00-07:00'
---

**Status:** active. **Where:**
[codebase-memory-mcp](../modules/codebase-memory-mcp.md).

## Context

Upstream codebase-memory-mcp had no Nix language support, so the code graph
was blind to this repo's primary language.

## Decision

- Consume `github:kriswill/codebase-memory-mcp/nix` — the fork adds Nix
  symbol extraction and flake-topology passes (submitted upstream as PR #19);
  rebase the fork onto upstream when bumping.
- The fork's darwin module exposes `services.codebase-memory-mcp.{enable,package}`
  (renamed from `kriswill.codebase-memory.*`; tracked in `b64c2ca`).
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
- [kriswill/codebase-memory-mcp PR #19](https://github.com/kriswill/codebase-memory-mcp)
