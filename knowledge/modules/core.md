---
type: Darwin Module
title: Core
description: The always-on darwin system baseline shared by every host — stateVersion, primary user, baseline packages, touch-ID sudo, fonts, shell enables, nix/nixpkgs settings.
resource: modules/darwin/core.nix
tags: [darwin-module]
timestamp: '2026-06-28T22:44:49-07:00'
---

The always-on darwin system baseline shared by every host: stateVersion,
primary user, baseline packages (iproute2mac, pstree, glow,
codebase-memory-mcp CLI), touch-ID sudo (pam-reattach), fonts, fish/zsh
enables, `nix.enable = false` (Determinate owns nix), and
`allowUnfree = false`. The rebuild helpers live in [nh](nh.md).

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/core.nix`](../../modules/darwin/core.nix)
