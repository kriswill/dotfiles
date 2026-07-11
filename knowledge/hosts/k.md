---
type: Host
title: k
description: k - my personal macbook pro M1 max, 64GB RAM.
resource: modules/hosts/k/default.nix
tags: [host]
timestamp: '2026-07-11T12:40:00-07:00'
---

k - my personal macbook pro M1 max, 64GB RAM.

Imports every [darwin-class module](../modules/index.md); host-selective features
are opted into below per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Host-selective features

- [apple-container](../modules/apple-container.md)
- [claude-account-selector](../modules/claude-account-selector.md)
- [codebase-memory-mcp](../modules/codebase-memory-mcp.md)
- [podman-desktop](../modules/podman-desktop.md)

## Secrets

Consumes [sops](../modules/sops.md) secrets: `sops-smoke-test` (end-to-end
decryption proof) and `ssh-private-hosts` — a dedicated sops file
(`ssh-hosts.yaml`) deployed to `~/.ssh/config.d/private-hosts` so private
`Host` entries stay out of the public repo
([decision](../decisions/ssh-private-hosts.md)).

## Source

- Host module: [`modules/hosts/k/default.nix`](../../modules/hosts/k/default.nix)
