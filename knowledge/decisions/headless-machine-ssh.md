---
type: Decision
title: Give Headless Mini Its Own SSH Authentication Key
description: 'Use a mini-only sops-encrypted machine key for outgoing SSH, authorize its public key across the managed hosts, and keep Git signing on its separate agent.'
tags: [ssh, secrets, darwin, headless]
status: stable
generated: { by: codex/gpt-6, at: 2026-11-13T11:25:04-08:00 }
sources:
  - id: ssh-config
    resource: https://man.openbsd.org/ssh_config
    title: OpenSSH client configuration
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix secret provisioning
---

**Where:** [mini's SSH client](../modules/ssh-client.md),
[darwin core](../modules/core.md), and [nebula user k](../modules/users-k.md).

## Context

On 2026-11-13, 54 seconds after mini booted, an incoming Herdr connection
started its core, which reconnected to saved machines `k` and `nebula`.
The shared SSH config selected mini's interactive 1Password agent.
Authorization requests timed out repeatedly until a person unlocked it.
The existing [headless Git signing agent](headless-git-signing-agent.md)
solved commit signatures only, leaving this SSH dependency intact.

## Decision

Generate a separate Ed25519 authentication key. Encrypt its private half
for [mini's](../hosts/mini.md) existing age recipient in a dedicated sops
file, and deploy it to user `k` through [sops-nix](../modules/sops.md).[^sops-nix]
Only the public half is added to every managed host's authorized keys.
Keep the personal key, Git signing key, and SSH host identity unchanged.

A host-local include selects the file and disables agent use and forwarding
before the shared defaults. Changing only `SSH_AUTH_SOCK` would not work:
the existing explicit `IdentityAgent` overrides that environment variable.[^ssh-config]

## Consequences

Mini can authenticate unattended, including after reboot. As requested,
its key grants user `k` access to all managed peers. The private key is
readable by `k` at runtime; sops protects its repository copy, rather than
making it non-exportable like the separate signing-agent setup. New Git
hosting destinations need their own authorization of this public key.

The work Mac was offline during rollout and needs a later rebuild. The
live bootstrap and rotation procedure are recorded in the
[SSH client module](../modules/ssh-client.md).

[^ssh-config]: `IdentityAgent` overrides `SSH_AUTH_SOCK`; `none` disables agent use.
[^sops-nix]: Encrypted inputs can be public; private values are decrypted at runtime.
