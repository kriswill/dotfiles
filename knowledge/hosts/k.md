---
type: Host
title: k
description: k - my personal macbook pro M1 max, 64GB RAM.
resource: modules/hosts/k/default.nix
tags: [host]
timestamp: '2026-07-03T17:53:43+00:00'
---

k - my personal macbook pro M1 max, 64GB RAM.

Imports every [darwin module](../modules/index.md); host-selective features
are opted into below per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Host-selective features

- [apple-container](../modules/apple-container.md)
- [claude-account-selector](../modules/claude-account-selector.md)
- [codebase-memory-mcp](../modules/codebase-memory-mcp.md)
- [podman-desktop](../modules/podman-desktop.md)

## Source

- Host module: [`modules/hosts/k/default.nix`](../../modules/hosts/k/default.nix)
