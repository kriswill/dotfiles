---
type: NixOS Module
title: Nebula Machine SSH Client
description: 'OpenSSH client identity for nebula, decrypted by sops-nix for unattended Herdr connections to managed machines independently of the root-only SSH server identity.'
resource: modules/hosts/nebula/ssh-client.nix
tags: [nixos-module, host-specific, ssh, secrets]
generated: { by: codex/gpt-6, at: 2026-11-13T11:52:28-08:00 }
sources:
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix secret provisioning
  - id: ssh-config
    resource: https://man.openbsd.org/ssh_config
    title: OpenSSH client configuration
---

[nebula](../hosts/nebula.md) had a server host key but no user client key on
2026-11-13. Its new Ed25519 client key is generated locally, encrypted only
to its existing age recipient, and deployed by sops-nix as user `k`, mode
`0400`, at `/home/k/.ssh/id_ed25519_nebula`.[^sops-nix]

The existing `/etc/ssh/ssh_host_ed25519_key` identifies the SSH server and
remains root-only. It is not reused for user authentication. Nebula also
configures `sops.age.keyFile = /root/.config/sops/age/keys.txt`; its existing
recipient in `.sops.yaml` differs from the age identity derived from the
current server public key. Retain that working recipient when encrypting
client secrets. Activation successfully decrypted the new key using the
existing sops configuration; do not replace the recipient merely to match
the current server key.

A system tmpfiles link installs `~/.ssh/config.d/00-machine-key`; the
[private-hosts module](ssh-private-hosts.md) already creates the directories.
The shared [machine policy](../../lib/ssh-machines.nix) used by
[k](ssh-client.md) selects the client file and disables agent use/forwarding
only for managed aliases. GitHub and other destinations keep the personal
1Password defaults.[^ssh-config]

[Herdr on nebula](nebula-herdr.md) invokes ordinary SSH for saved targets
`k@k.home.lan` and `k@mini`. No extra herdr-core secret or agent is needed.
[Darwin core](core.md) and [nebula user k](users-k.md) consume the common
public-key list, retaining the personal key. See the
[machine SSH decision](../decisions/headless-machine-ssh.md).

## Deployment and verification

Use [nrs](nrs.md) from the real checkout path, as the normal user. On
2026-11-13 activation reached generation 235; the client path resolved into
`/run/secrets.d/` with mode `0400`. Fresh non-multiplexed SSH to k and mini
selected `id_ed25519_nebula` and succeeded, including fresh Herdr `hello`
handshakes. `ssh -G github.com` retained
`/home/k/.1password/agent.sock`.

## Source

- [Host module](../../modules/hosts/nebula/ssh-client.nix)
- [Public key](../../modules/hosts/nebula/ssh-client.pub)
- [Encrypted key](../../modules/hosts/nebula/ssh-client.yaml)
- [Encryption rules](../../.sops.yaml)

[^sops-nix]: Secret paths, ownership and age identities are configurable independently of sshd.
[^ssh-config]: IdentityAgent overrides SSH_AUTH_SOCK; none disables agent use.
