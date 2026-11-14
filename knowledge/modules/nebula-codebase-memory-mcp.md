---
type: NixOS Module
title: Codebase Memory Mcp
description: 'Keeps the optional codebase-memory daemon and control CLI disabled on nebula while retaining the fork module.'
resource: modules/hosts/nebula/codebase-memory-mcp.nix
tags: [nixos-module, host-specific]
generated: { by: codex/gpt-6, at: 2026-11-13T23:52:00-08:00 }
---

Explicitly disables [codebase-memory-mcp](codebase-memory-mcp.md) on
[nebula](../hosts/nebula.md), matching the fleet-wide installation removal.
The fork's NixOS module remains imported, so the option and package exports
remain available without installing the daemon or `cbm-ctl`. Normal NRS
activation applies this configuration; existing index data is preserved.

## Source

- Module: [`modules/hosts/nebula/codebase-memory-mcp.nix`](../../modules/hosts/nebula/codebase-memory-mcp.nix)
