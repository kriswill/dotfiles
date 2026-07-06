---
type: Dual Module
title: Codebase Memory Mcp
description: Supervised codebase-memory-mcp MCP daemon (semantic code graph + HTTP UI on :9749) from the kriswill fork, whose flake ships both OS modules — a launchd user agent on darwin, a systemd user service on NixOS — plus the cbm-ctl control CLI.
resource: modules/darwin/codebase-memory-mcp.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T10:23:09-07:00'
---

Both class files are one-line re-exports: the fork
(`github:kriswill/codebase-memory-mcp/nix`, see the
[fork decision](../decisions/codebase-memory-fork.md)) ships
`darwinModules.codebase-memory-mcp` (launchd user agent
`org.nixos.codebase-memory-mcp`, logs under `~/Library/Logs/`) and
`nixosModules.codebase-memory-mcp` (systemd user service
`codebase-memory-mcp.service`, logs in the user journal), and each re-export
mounts the matching one into the Dendritic module set. The modules are twins
with the same option surface (`services.codebase-memory-mcp.{enable,package,port}`)
and default `package` to the fork's own build — no overlay wiring needed
(the flake's overlay / `perSystem` exports cover `pkgs.codebase-memory-mcp`
consumers separately).

The binary has no daemon mode (stdio MCP server exits on stdin EOF), so both
supervisors run the fork's `cbm-daemon` FIFO wrapper in the foreground; the
fork's `cbm-tools` also provides `cbm-ctl`
(status / flush / commit / start·stop·restart / logs), which selects launchctl
or `systemctl --user` at compile time.

Gated per host: enabled on [k](../hosts/k.md) and
[SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md) (darwin, per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)) and on
[nebula](../hosts/nebula.md) via
[nebula-codebase-memory-mcp](nebula-codebase-memory-mcp.md); auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Citations

- Fork supervision layer: [nix/tools/README.md](https://github.com/kriswill/codebase-memory-mcp/blob/nix/nix/tools/README.md)
- Upstream server: [DeusData/codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp)

## Source

- darwin module: [`modules/darwin/codebase-memory-mcp.nix`](../../modules/darwin/codebase-memory-mcp.nix)
- NixOS module: [`modules/nixos/codebase-memory-mcp.nix`](../../modules/nixos/codebase-memory-mcp.nix)
