---
type: Darwin Module
title: Podman Desktop
description: Podman Desktop.
resource: modules/darwin/podman-desktop.nix
tags: [darwin-module]
timestamp: '2026-07-03T10:23:09-07:00'
---

Podman Desktop.

Imported on every darwin host but disabled by default — hosts opt in with
`programs.podman-desktop.enable = true;` (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)); auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/podman-desktop.nix`](../../modules/darwin/podman-desktop.nix)
- Options under: `programs.podman-desktop`
- Stow package: [`home/podman-desktop/`](../../home/podman-desktop/) — see the [stow tree pattern](../patterns/stow-tree.md)
