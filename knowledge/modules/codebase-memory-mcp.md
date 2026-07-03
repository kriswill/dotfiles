---
type: Darwin Module
title: Codebase Memory Mcp
description: codebase-memory-mcp ships its nix-darwin module in our kriswill/codebase-memory-mcp `nix` fork (nix/darwin/module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module.
resource: modules/darwin/codebase-memory-mcp.nix
tags: [darwin-module]
timestamp: '2026-07-03T10:23:09-07:00'
---

codebase-memory-mcp ships its nix-darwin module in our kriswill/codebase-memory-mcp `nix` fork (nix/darwin/module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module. The module defaults services.codebase-memory-mcp.package to the fork's own package, so no overlay or pkgs wiring is needed. Enable per host with `services.codebase-memory-mcp.enable = true;`.

Imported on every darwin host but disabled by default — hosts opt in with
`services.codebase-memory-mcp.enable = true;` (the options live in the fork's
darwin module; see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)); auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/codebase-memory-mcp.nix`](../../modules/darwin/codebase-memory-mcp.nix)
