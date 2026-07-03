---
type: Darwin Module
title: Codebase Memory Mcp
description: codebase-memory-mcp launchd daemon, mounted into hosts k + SOC.
resource: modules/hosts/codebase-memory-mcp.nix
tags: [darwin-module, host-mounted]
timestamp: '2026-07-03T10:23:09-07:00'
---

codebase-memory-mcp launchd daemon, mounted into hosts k + SOC. The nix-darwin module ships in our kriswill/codebase-memory-mcp `nix` fork (nix/darwin/module.nix) and defaults services.codebase-memory-mcp.package to the fork's own package, so no overlay or pkgs wiring is needed. (The CLI package itself is on every host via core.nix's systemPackages.).

Host-mounted feature ([SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md), [k](../hosts/k.md)) — merged
straight into the hosts' configurations per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/codebase-memory-mcp.nix`](../../modules/hosts/codebase-memory-mcp.nix)
