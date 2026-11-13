---
type: Darwin Module
title: Mini Machine SSH Client
description: 'OpenSSH client identity for headless mini, decrypted with sops-nix and trusted for user k across every managed host without contacting the 1Password agent.'
resource: modules/hosts/mini/ssh-client.nix
tags: [darwin-module, host-specific, ssh, secrets]
generated: { by: codex/gpt-6, at: 2026-11-13T11:29:18-08:00 }
sources:
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix secret provisioning
  - id: ssh-config
    resource: https://man.openbsd.org/ssh_config
    title: OpenSSH client configuration
---

[mini](../hosts/mini.md) stores its Ed25519 authentication key in
[`ssh-client.yaml`](../../modules/hosts/mini/ssh-client.yaml), encrypted only
for its existing age recipient. [sops-nix](sops.md) deploys `ssh-client-key`
as `k`, mode `0400`, at `~/.ssh/id_ed25519_mini`; the private key never
enters the Nix store in plaintext.[^sops-nix]

Activation links a Nix-built config into `~/.ssh/config.d/00-machine-key`.
The shared SSH config includes it before the 1Password defaults, so
`IdentityAgent none`, `IdentitiesOnly yes`, and the explicit `IdentityFile`
win. `ForwardAgent no` avoids forwarding unrelated credentials. This
applies to all outgoing SSH on mini; other hosts retain their existing
client authentication.[^ssh-config]

Trust is separate: the public file `ssh-client.pub` is consumed by
[darwin core](core.md) and [nebula's user module](users-k.md). The existing
personal key remains authorized. The [Git signing agent](git-signing-agent.md)
uses a different key and socket. Rationale: [headless machine SSH](../decisions/headless-machine-ssh.md).

## Deployment and verification

On 2026-11-13 the exact private key was bootstrapped as a local `0400` file,
and the Nix-built client config linked in. Fresh non-multiplexed SSH
connections to `k` and `nebula` confirmed the machine-key fingerprint;
agent use was disabled. Their user `authorized_keys` files were updated
without removing existing keys. Activation has since replaced the bootstrap
file with the sops-managed symlink; its public key, owner `k`, and mode `0400`
were verified, followed by fresh logins to both peers. `nrs --status` reported
generation 22 as both running and boot default, with consistent state.

Use [nrs](nrs.md), as the normal user without a `sudo` prefix, for rebuilding,
switching, and activating on every host. It installs the sops-managed key
on mini and Nix-managed trust on peers. The offline work Mac is deferred
until it returns.

Check `ssh -G k` for `identityagent none` and `id_ed25519_mini`, then
`ssh -o BatchMode=yes -o ControlPath=none k hostname` (also `nebula`).
`ssh-keygen -lf modules/hosts/mini/ssh-client.pub` prints the fingerprint.

## Rotation and revocation

Generate a fresh key outside the repository, encrypt it with the
`ssh-client.yaml` creation rule, and replace the public file. Distribute the
new public key to peers before switching mini; remove the old key from
both Nix configuration and any bootstrap `~/.ssh/authorized_keys` entries.
Revocation requires removing both copies and closing existing SSH sessions.
Never reuse the Git signing key for machine login.

## Source

- [Host module](../../modules/hosts/mini/ssh-client.nix)
- [Public key](../../modules/hosts/mini/ssh-client.pub)
- [Encryption rules](../../.sops.yaml)

[^sops-nix]: Secret `sopsFile`, `owner`, `mode`, and `path` control deployment.
[^ssh-config]: OpenSSH uses the first obtained scalar value; `IdentityAgent none` disables agent use, while `IdentityFile` selects the on-disk key.
