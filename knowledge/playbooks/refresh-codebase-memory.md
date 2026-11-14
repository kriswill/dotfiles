---
type: Playbook
title: Refresh the Codebase-memory Index
description: Bootstrap or refresh the code-graph index the codebase-memory MCP server keeps for this repo.
tags: [mcp, codebase-memory, maintenance]
generated: { by: codex/gpt-6, at: 2026-11-13T23:52:00-08:00 }
---

Background in [codebase-memory via Nix-aware fork](../decisions/codebase-memory-fork.md);
the optional server module is [codebase-memory-mcp](../modules/codebase-memory-mcp.md).
It is disabled fleet-wide and no longer declared in `.mcp.json`. The examples
below apply only after an explicit optional installation and client setup;
existing index data is retained.

## Examples

- **Normal operation:** nothing — the watcher (`auto_index=true`) refreshes
  the index as files change.
- **Verify state:** the `index_status` MCP tool reports node/edge counts and
  the indexed commit; `.codebase-memory/artifact.json` holds the same
  metadata on disk.
- **Bootstrap / full rebuild** (schema changes, corruption, fork bumps):
  call the `delete_project` MCP tool, then `index_repository` with
  `persistence: true` so the graph lands at `.codebase-memory/graph.db.zst`.

The artifact path is gitignored for now — see the decision record for the
trade-off being evaluated.
