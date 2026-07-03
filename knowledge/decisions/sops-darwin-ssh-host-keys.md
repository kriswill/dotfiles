---
type: Decision
title: sops-nix on Darwin via SSH-Host-Key Age Identities
description: Every host's sops age identity derives from its SSH host key (ssh-to-age) — no new key material; darwin imports sops-nix's darwinModules.sops universally and stays inert until a host defines secrets.
tags: [secrets, sops, age, darwin]
timestamp: '2026-07-03T14:00:00-07:00'
---

**Status:** active. **Where:** [.sops.yaml](../../.sops.yaml),
[modules/darwin/sops.nix](../../modules/darwin/sops.nix),
[modules/hosts/k/default.nix](../../modules/hosts/k/default.nix).

## Context

nebula already ran sops-nix (age recipient generated at install; secrets:
user password hash, SSH host keys). The Macs had zero secrets machinery, but
the shared ssh config's "sops-managed internal hosts" comment anticipated it,
and the [unification](nixos-darwin-unification.md) made one secrets story
desirable.

## Decision

- `sops-nix` becomes an explicit flake input (snowglobe-lib `follows` it, so
  there is exactly one copy).
- `modules/darwin/sops.nix` (universal) imports `darwinModules.sops` and sets
  `sops.age.sshKeyPaths = [ /etc/ssh/ssh_host_ed25519_key ]` — the age
  identity **derives from the SSH host key** via ssh-to-age, so onboarding a
  host is `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub` → add the anchor +
  creation rule to `.sops.yaml`. No new private key to generate, back up, or
  rotate separately.
- Per-host secrets convention (both OSes): `modules/hosts/<host>/secrets.yaml`
  + `sops.defaultSopsFile` in the host file. Host `k` carries an encrypted
  smoke-test secret proving darwin decryption end-to-end; `mini` and
  `SOC-Kris-Williams` recipients are TODO until run on those machines.
- gpg is unrelated to secrets/signing here: gpg-agent is enabled class-wide on
  both OSes (`modules/{darwin,nixos}/gpg.nix`) solely to back `pass`
  (pass-xdg on both OSes) and ad-hoc gpg, with `enableSSHSupport = false` —
  SSH auth and git signing stay with the 1Password agent (`op-ssh-sign`).

## Consequences

Rotating a Mac's SSH host key re-keys its sops identity — re-encrypt that
host's secrets.yaml after rotation (`sops updatekeys`). The helium-config age
key (1Password-held) remains a separate mechanism by design; see
[config/README.md](../../config/README.md).
