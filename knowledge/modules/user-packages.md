---
type: Darwin Module
title: User Packages
description: 'The primary user''s per-user CLI toolbox on darwin (users.users.k.packages) — everyday tools from bat/fzf/ripgrep to lazygit and uv, and the darwin provisioner of the Bun and Node runtimes.'
resource: modules/darwin/user-packages.nix
tags: [darwin-module]
timestamp: '2026-07-04T00:00:00-07:00'
---

The darwin per-user package list (`users.users.k.packages`): the everyday
CLI toolbox — bat, fzf, ripgrep, lazygit, jq, just, uv, nix-tree, … —
installed for the primary user rather than system-wide. It is also the
darwin provisioner of the JS runtimes: [bun](../bun-runtime.md) and
`nodejs_24` live here, where NixOS provides them system-wide via
[node-runtime](node-runtime.md) instead (there is no darwin twin of that
module); [neovim](neovim.md)'s darwin twin separately carries a plain
`nodejs` in its system-wide tool list for LSP servers.

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/user-packages.nix`](../../modules/darwin/user-packages.nix)
