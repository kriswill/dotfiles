---
type: Dual Module
title: Codebase Memory Mcp
description: 'Supervised codebase-memory-mcp MCP daemon (semantic code graph + HTTP UI on :9749) from the kriswill fork, whose flake ships both OS modules — a launchd user agent on darwin, a systemd user service on NixOS — plus the cbm-ctl control CLI.'
resource: modules/darwin/codebase-memory-mcp.nix
tags: [darwin-module, nixos-module]
generated: { by: codex/gpt-6, at: 2026-11-14T00:08:00-08:00 }
sources:
  - id: fork-supervision-layer-nix-tools-readme-md
    resource: https://github.com/kriswill/codebase-memory-mcp/blob/nix/nix/tools/README.md
    title: 'Fork supervision layer: nix/tools/README.md'
  - id: upstream-server-deusdata-codebase-memory-mcp
    resource: https://github.com/DeusData/codebase-memory-mcp
    title: 'Upstream server: DeusData/codebase-memory-mcp'
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

Disabled on every host as of 2026-11-13: [k](../hosts/k.md),
[SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md) and
[nebula](../hosts/nebula.md) explicitly disable the service; mini retains
its disabled default. The shared [darwin baseline](core.md) no longer
installs the CLI, and the repository's `.mcp.json` no longer launches it.
The flake input, package exports, overlay and both module re-exports remain
available for optional use. Existing indexes are retained.

K's generation 290 activation and following reboot verified the job,
executable and process absent. Other hosts apply removal on their next normal
NRS activation. K's measured generation-289 launch interval was
40.656 seconds, concurrent with other startup work; removing it does not
establish an equal reduction in interactive or remote readiness. See the
[startup comparison](../../docs/shell-startup-performance.md) and
[fork decision](../decisions/codebase-memory-fork.md).

## Source

- darwin module: [`modules/darwin/codebase-memory-mcp.nix`](../../modules/darwin/codebase-memory-mcp.nix)
- NixOS module: [`modules/nixos/codebase-memory-mcp.nix`](../../modules/nixos/codebase-memory-mcp.nix)
