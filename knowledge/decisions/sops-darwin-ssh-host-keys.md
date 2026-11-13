---
type: Decision
title: sops-nix on Darwin via SSH-Host-Key Age Identities
description: 'Darwin derives its sops age identities from SSH host keys and imports sops-nix universally; per-host secrets now include Mini''s noninteractive signing bootstrap and separate SSH client identity.'
tags: [secrets, sops, age, darwin]
generated: { by: codex/gpt-6, at: 2026-11-13T14:43:17-08:00 }
---

**Status:** active. **Where:** [.sops.yaml](../../.sops.yaml),
[modules/darwin/sops.nix](../../modules/darwin/sops.nix),
[modules/hosts/k/default.nix](../../modules/hosts/k/default.nix).

## Original context (2026-07-03)

nebula already ran sops-nix (age recipient generated at install; secrets:
user password hash, SSH host keys). The Macs had zero secrets machinery, but
the shared ssh config's "sops-managed internal hosts" comment anticipated it,
and the [unification](nixos-darwin-unification.md) made one secrets story
desirable.

## Decision

- `sops-nix` becomes an explicit flake input (snowglobe-factory `follows` it, so
  there is exactly one copy).
- `modules/darwin/sops.nix` (universal) imports `darwinModules.sops` and sets
  `sops.age.sshKeyPaths = [ /etc/ssh/ssh_host_ed25519_key ]` — the age
  identity **derives from the SSH host key** via ssh-to-age, so onboarding a
  host is `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub` → add the anchor +
  creation rule to `.sops.yaml`. No new private key to generate, back up, or
  rotate separately.
- Per-host secrets convention (both OSes): `modules/hosts/<host>/secrets.yaml`
  + `sops.defaultSopsFile` in the host file. Host `k` carries an encrypted
  smoke-test secret proving darwin decryption end-to-end. At the original
  rollout, `mini` and `SOC-Kris-Williams` recipients were still TODO;
  Mini's subsequent provisioning is recorded below.
- gpg is unrelated to secrets/signing here: gpg-agent is enabled class-wide on
  both OSes (`modules/{darwin,nixos}/gpg.nix`) solely to back `pass`
  (pass-xdg on both OSes) and ad-hoc gpg, with `enableSSHSupport = false` —
  SSH auth and Git signing initially remained with the 1Password agent
  (`op-ssh-sign` for signing). That was the rollout state, not a requirement
  to keep unattended workflows dependent on desktop authentication.

## Current state (2026-11-13)

[Mini](../hosts/mini.md) has an age recipient and creation rules in
`.sops.yaml`. Its [signing service](../modules/git-signing-agent.md) uses a
root-only SOPS-decrypted 1Password service-account token to load a signing
key into an in-memory agent; see [headless Git signing](headless-git-signing-agent.md).
Its [SSH client](../modules/mini-ssh-client.md) uses a separate SOPS-decrypted
client key owned by k, with `IdentityAgent none`. These two paths worked
after the generation-28 reboot without desktop authentication. The signing
token does not provision general per-agent vault access.

[Headless machine SSH](headless-machine-ssh.md) also covers k and nebula,
with managed-destination scope on those hosts; personal 1Password paths
remain outside that scope. Do not conflate client keys, SSH server keys,
SOPS identities and Git signing keys. In particular,
[nebula](../modules/nebula-ssh-client.md) retains its existing age key file
and recipient, which differs from the identity derived from its current SSH
server key. The Darwin derivation rule above is not a fleet-wide assertion
about every current SOPS identity. `SOC-Kris-Williams` remains TODO in
`.sops.yaml`; its deployment is unverified while offline.

## Consequences

Rotating a Mac's SSH host key re-keys its sops identity — re-encrypt that
host's secrets.yaml after rotation (`sops updatekeys`). The helium-config age
key (1Password-held) remains a separate mechanism by design; see
[config/README.md](../../config/README.md).
