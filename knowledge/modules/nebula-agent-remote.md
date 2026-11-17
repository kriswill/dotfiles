---
type: NixOS Module
title: Agent Remote on nebula
description: 'Enable-gate that turns on the second, key-only sshd on port 2122 for nebula, so Herdr reaches it on the same port as the Macs.'
resource: modules/hosts/nebula/agent-remote.nix
tags: [nixos-module, host-specific, ssh]
generated: { by: claude/fable-5.2, at: 2026-11-16T22:40:00-08:00 }
---

Sets `services.agent-remote.enable = true` on [nebula](../hosts/nebula.md),
per the [host-mounted modules pattern](../patterns/host-mounted-modules.md).
The port stays at the module default, 2122. Everything the service does,
and how it differs from the Macs' launchd daemon, is under
[Agent Remote](agent-remote.md).

## Source

- Module: [`modules/hosts/nebula/agent-remote.nix`](../../modules/hosts/nebula/agent-remote.nix)
