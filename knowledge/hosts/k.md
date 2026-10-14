---
type: Host
title: k
description: 'k - my personal macbook pro M1 max, 64GB RAM.'
resource: modules/hosts/k/default.nix
tags: [host]
generated: { by: okflight/0.4.0, at: 2026-07-11T12:40:00-07:00 }
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

## Apps

Installs P4V, P4Admin and P4Merge 2026.3 into `/Applications/Nix Apps`
through `environment.systemPackages`, built with `dontStrip` so Perforce's
signature survives ([decision](../decisions/p4v-nix-apps-dont-strip.md)).

## Secrets

Consumes [sops](../modules/sops.md) secrets: `sops-smoke-test` (end-to-end
decryption proof), plus the shared private ssh hosts file via the gated
[ssh-private-hosts module](../modules/ssh-private-hosts.md)
([decision](../decisions/ssh-private-hosts.md)).

## Source

- Host module: [`modules/hosts/k/default.nix`](../../modules/hosts/k/default.nix)
