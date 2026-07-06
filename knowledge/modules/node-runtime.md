---
type: NixOS Module
title: Node Runtime
description: 'System-wide Node.js + Bun — infrastructure, not dev convenience: npx-launched MCP servers (Claude Code plugins) silently fail on NixOS without a node on PATH.'
resource: modules/nixos/node-runtime.nix
tags: [nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Installs `pkgs.nodejs` (`node`/`npm`/`npx`) and
[`pkgs.bun`](../bun-runtime.md) system-wide.
NixOS ships no node by default, but Claude Code's MCP servers are launched
via `npx` (e.g. the chrome-devtools-mcp plugin), and without a runtime on
PATH they silently fail to start. Bun doubles as the preferred fast
runtime/package manager and an `npx`-compatible runner.

Hidden inter-module dependency: [neovim](neovim.md)'s nixos twin deliberately
omits `nodejs` from its tool list and relies on this module for it (its
`vtsls` is separately rebuilt against `nodejs-slim_24` to avoid dragging a
second node into the closure). There is no darwin twin — on macOS the
runtimes come from [user-packages](user-packages.md), which installs both
`bun` and `nodejs_24` in the primary user's per-user packages, while
[neovim](neovim.md)'s darwin twin additionally carries a plain `nodejs` in
its system-wide tool list.

Mounted ungated on every NixOS host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/node-runtime.nix`](../../modules/nixos/node-runtime.nix)
