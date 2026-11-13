---
type: Decision
title: Use Per-Machine SSH Keys for Unattended Managed Access
description: 'Give mini, k, and nebula separate sops-encrypted client identities for unattended managed access while preserving personal authentication and separate server/signing keys.'
tags: [ssh, secrets, darwin, headless]
status: stable
generated: { by: codex/gpt-6, at: 2026-11-13T11:54:45-08:00 }
sources:
  - id: ssh-config
    resource: https://man.openbsd.org/ssh_config
    title: OpenSSH client configuration
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix secret provisioning
---

**Where:** [mini's SSH client](../modules/mini-ssh-client.md),
[k's SSH client](../modules/ssh-client.md),
[nebula's SSH client](../modules/nebula-ssh-client.md),
[darwin core](../modules/core.md), and [nebula user k](../modules/users-k.md).

## Context

On 2026-11-13, 54 seconds after mini booted, an incoming Herdr connection
started its core, which reconnected to saved machines `k` and `nebula`.
The shared SSH config selected mini's interactive 1Password agent.
Authorization requests timed out repeatedly until a person unlocked it.
The existing [headless Git signing agent](headless-git-signing-agent.md)
solved commit signatures only, leaving this SSH dependency intact.

## Decision

Generate a separate Ed25519 authentication key on each of
[mini](../hosts/mini.md), [k](../hosts/k.md), and
[nebula](../hosts/nebula.md). Encrypt each private half only to that
host's existing age recipient in a dedicated sops file, and deploy it to
user `k` through [sops-nix](../modules/sops.md).[^sops-nix]
Only the public half is added to every managed host's authorized keys.
Keep the personal key, Git signing key, and SSH host identity unchanged.

A host-local include selects the file and disables agent use and forwarding
before the shared defaults. Changing only `SSH_AUTH_SOCK` would not work:
the existing explicit `IdentityAgent` overrides that environment variable.[^ssh-config]

Mini applies its identity globally. The interactive hosts k and nebula
apply theirs only to exact managed aliases, preserving personal agent
authentication for GitHub and work destinations. A single
[public-key list and host policy](../../lib/ssh-machines.nix) keeps the
darwin and NixOS trust declarations aligned. Herdr uses these SSH settings
without its own key copy.

Nebula's existing machine key was its root-only server identity; no client
key existed. Keep that role separate. Its working sops recipient also
differs from the current server key and uses the existing root age keyfile,
as recorded in [nebula's client module](../modules/nebula-ssh-client.md).

## Consequences

All three machines can authenticate unattended to managed peers, including
after reboot. Each public key grants user `k` access across the fleet. The private key is
readable by `k` at runtime; sops protects its repository copy, rather than
making it non-exportable like the separate signing-agent setup. New Git
hosting destinations on mini need their own authorization of its public key;
k and nebula continue using their existing personal configuration there.

The work Mac was offline during rollout and needs a later rebuild. The
live bootstrap and rotation procedure are recorded in the
[mini SSH client module](../modules/mini-ssh-client.md). Initial mini
support landed in `0ec7101e`. Rebuild, switch, and activate exclusively
through [nrs](../modules/nrs.md) on each host; staged or unstaged unrelated
checkout edits must survive the main reconciliation.

[^ssh-config]: `IdentityAgent` overrides `SSH_AUTH_SOCK`; `none` disables agent use.
[^sops-nix]: Encrypted inputs can be public; private values are decrypted at runtime.
