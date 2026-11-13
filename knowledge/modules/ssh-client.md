---
type: Darwin Module
title: K Machine SSH Client
description: 'OpenSSH client identity for k, decrypted by sops-nix for unattended Herdr connections to managed machines while other destinations retain personal authentication.'
resource: modules/hosts/k/ssh-client.nix
tags: [darwin-module, host-specific, ssh, secrets]
generated: { by: codex/gpt-6, at: 2026-11-13T11:52:28-08:00 }
sources:
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix secret provisioning
  - id: ssh-config
    resource: https://man.openbsd.org/ssh_config
    title: OpenSSH client configuration
---

[k](../hosts/k.md) has its own Ed25519 client key, encrypted only to its
existing age recipient. [sops-nix](sops.md) installs it as user `k`, mode
`0400`, at `~/.ssh/id_ed25519_k`; plaintext stays out of the repository and
Nix store.[^sops-nix]

Activation links `~/.ssh/config.d/00-machine-key` before the shared
1Password defaults. The host list and config template come from
[`lib/ssh-machines.nix`](../../lib/ssh-machines.nix), shared with
[nebula](nebula-ssh-client.md). Exact managed host names and their LAN/mDNS
aliases select the file, `IdentityAgent none`, `IdentitiesOnly yes`, and
`ForwardAgent no`. Other destinations, including GitHub, retain the existing
personal agent configuration. A trailing `Host *` keeps subsequent includes
from inheriting this conditional scope.[^ssh-config]

[Herdr](herdr.md) uses these ordinary OpenSSH settings for its saved targets
`k@nebula.home.lan` and `k@mini`; it needs no separate key setting or secret
copy. Unlike [headless mini](mini-ssh-client.md), this interactive Mac does
not apply the machine identity to every destination. Rationale:
[headless machine SSH](../decisions/headless-machine-ssh.md).

The shared public-key list grants all three machine identities user `k`
access through [darwin core](core.md) and [nebula user k](users-k.md), while
retaining the personal key. Apply with [nrs](nrs.md) as the normal user.
Use `ssh -G nebula.home.lan` and a fresh
`ssh -o BatchMode=yes -o ControlPath=none nebula.home.lan hostname` to verify
selection and authentication; repeat for mini. `ssh -G github.com` should
still select the personal agent.

## Deployment and verification

On 2026-11-13, [nrs](nrs.md) activated generation 287 with matching running
and boot-default state. The client key resolved into `/run/secrets.d/`
with owner `k` and mode `0400`. Fresh SSH and Herdr `hello` handshakes to
nebula and mini used the machine fingerprint; GitHub still selected the
1Password agent.

## Source

- [Host module](../../modules/hosts/k/ssh-client.nix)
- [Public key](../../modules/hosts/k/ssh-client.pub)
- [Encrypted key](../../modules/hosts/k/ssh-client.yaml)
- [Encryption rules](../../.sops.yaml)

[^sops-nix]: Per-secret owner, mode, and path control runtime deployment.
[^ssh-config]: OpenSSH uses the first obtained scalar value; IdentityAgent none disables agent use.
