---
type: NixOS Module
title: Nebula Git Signing Agent
description: 'Flips services.git-signing-agent on for nebula with the shared automation key, so commits made there (by AI harnesses or at the keyboard) sign through a root-loaded ssh-agent instead of waiting on 1Password.'
resource: modules/hosts/nebula/git-signing-agent.nix
tags: [nixos-module, host-specific, git, secrets]
generated: { by: claude-code/fable-5.2, at: 2026-11-14T13:40:00-08:00 }
sources:
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix (per-file sopsFile, build-time validation of declared keys)
---

Enables the nixos twin of [git-signing-agent](git-signing-agent.md) on
[nebula](../hosts/nebula.md) for user `k`, merged straight into the host's
configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md). It
points the module at the two shared files beside the host directories:
`modules/hosts/git-signing.pub` and `modules/hosts/git-signing.yaml`, the
key [mini](../hosts/mini.md) and [k](../hosts/k.md) sign with too
([decision](../decisions/git-signing-key-in-sops.md)).

`enable` is `builtins.pathExists ../git-signing.yaml`, not `true`. sops-nix
checks every declared secret against its file at build time,[^sops-nix] so
an unconditional enable would break the build of any checkout where the key
file isn't tracked yet. With the guard that checkout builds and signs
through `op-ssh-sign`, as before, and deleting the file withdraws the key
from this host at its next [nrs](nrs.md).

The file is separate from nebula's own `secrets.yaml` because it is shared:
its recipients are k and nebula, not nebula alone. It does not touch
nebula's existing `op-sa-token`, which belongs to the
[gh wrapper](../decisions/op-service-account-token.md), not to signing.

Putting the key in the file, verifying, rotating and revoking:
[git-signing-agent-setup](../playbooks/git-signing-agent-setup.md).

## Source

- Module: [`modules/hosts/nebula/git-signing-agent.nix`](../../modules/hosts/nebula/git-signing-agent.nix)
- Public key: [`modules/hosts/git-signing.pub`](../../modules/hosts/git-signing.pub)
- Encryption rule: [`.sops.yaml`](../../.sops.yaml)

[^sops-nix]: sops-nix validates at build time that each `sops.secrets.<name>` key exists in its `sopsFile`.
