---
type: NixOS Module
title: Codebase Memory Mcp
description: Flips services.codebase-memory-mcp.enable on nebula — the supervised code-graph daemon (systemd user service) + cbm-ctl from the fork's NixOS module.
resource: modules/hosts/nebula/codebase-memory-mcp.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-06T04:14:27+00:00'
---

One-setting file: enables
[codebase-memory-mcp](codebase-memory-mcp.md) (the fork's NixOS module,
re-exported by `modules/nixos/codebase-memory-mcp.nix`) on
[nebula](../hosts/nebula.md) — merged straight into the host's configuration
per the [host-mounted modules pattern](../patterns/host-mounted-modules.md).
The nixos class is otherwise all-universal; this gate lives host-side so the
class module stays a pure re-export, mirroring how the darwin hosts flip the
same option in their `default.nix`.

## Source

- Module: [`modules/hosts/nebula/codebase-memory-mcp.nix`](../../modules/hosts/nebula/codebase-memory-mcp.nix)
