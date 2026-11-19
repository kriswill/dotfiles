---
type: Host
title: SOC-Kris-Williams
description: 'SOC-Kris-Williams - my work Apple M2 Pro, 32GB RAM hostname enforced by IT.'
resource: modules/hosts/SOC-Kris-Williams/default.nix
tags: [host]
generated: { by: codex/gpt-6, at: 2026-11-13T23:52:00-08:00 }
---

SOC-Kris-Williams - my work Apple M2 Pro, 32GB RAM hostname enforced by IT.

Imports every [darwin-class module](../modules/index.md); host-selective features
are opted into below per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Host-selective features

- [agent-remote](../modules/agent-remote.md): a second, key-only sshd on
  port 2122, independent of Remote Login.
- [apple-container](../modules/apple-container.md)
- [git-signing-agent](../modules/git-signing-agent.md): prompt-free commit
  signing with the shared key from `modules/hosts/git-signing.yaml`.
- [pam-tid-gate](../modules/pam-tid-gate.md): Touch ID for sudo only while
  someone can reach this MacBook's readers; otherwise the password.
- [podman-desktop](../modules/podman-desktop.md)
- [remote-login](../modules/remote-login.md)
- [alias-en0](../modules/alias-en0.md) (host-specific file)

## Source

- Host module: [`modules/hosts/SOC-Kris-Williams/default.nix`](../../modules/hosts/SOC-Kris-Williams/default.nix)
