---
type: Darwin Module
title: Codebase Memory Mcp
description: codebase-memory-mcp ships its nix-darwin module in our kriswill/codebase-memory-mcp `nix` fork (nix/darwin/module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module.
resource: modules/darwin/codebase-memory-mcp.nix
tags: [darwin-module]
timestamp: '2026-06-30T23:18:47-07:00'
---

codebase-memory-mcp ships its nix-darwin module in our kriswill/codebase-memory-mcp `nix` fork (nix/darwin/module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module. The module defaults services.codebase-memory-mcp.package to the fork's own package, so no overlay or pkgs wiring is needed. Enable per host with `services.codebase-memory-mcp.enable = true;`.

Follows the [module option pattern](../patterns/module-option-pattern.md), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/codebase-memory-mcp.nix`](../../modules/darwin/codebase-memory-mcp.nix)
