---
type: Host
title: SOC-Kris-Williams
description: SOC-Kris-Williams - my work Apple M2 Pro, 32GB RAM hostname enforced by IT.
resource: modules/hosts/SOC-Kris-Williams/default.nix
tags: [host]
timestamp: '2026-07-03T17:53:43+00:00'
---

SOC-Kris-Williams - my work Apple M2 Pro, 32GB RAM hostname enforced by IT.

Imports every [darwin module](../modules/index.md); host-selective features
are opted into below per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Host-selective features

- [apple-container](../modules/apple-container.md)
- [codebase-memory-mcp](../modules/codebase-memory-mcp.md)
- [podman-desktop](../modules/podman-desktop.md)
- [alias-en0](../modules/alias-en0.md) (host-specific file)

## Source

- Host module: [`modules/hosts/SOC-Kris-Williams/default.nix`](../../modules/hosts/SOC-Kris-Williams/default.nix)
