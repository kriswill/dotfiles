---
type: Darwin Module
title: Sops
description: sops-nix on macOS — universal secrets machinery whose age identity derives from the host SSH key; inert until a host declares secrets.
resource: modules/darwin/sops.nix
tags: [darwin-module]
generated: { by: codex/gpt-6, at: 2026-11-13T11:54:45-08:00 }
sources:
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix
---

Imports `sops-nix.darwinModules.sops` on every darwin host and points
`sops.age.sshKeyPaths` at `/etc/ssh/ssh_host_ed25519_key`, so each Mac's age
identity derives from its SSH host key (`ssh-to-age`) — no new key material
to manage. Universal but inert: nothing happens until a host declares
`sops.defaultSopsFile` + `sops.secrets.<name>` and `.sops.yaml` gains the
matching recipient anchor + creation rule. Mirrors
[nebula](../hosts/nebula.md)'s setup, which gets the NixOS sops module via
snowglobe-factory's `mkNixosHost` instead. Nebula additionally uses
`/root/.config/sops/age/keys.txt`; its existing recipient is distinct from
the current server key. See [nebula SSH client](nebula-ssh-client.md) before
changing that recipient.

Secrets install at activation through a launchd daemon
(`org.nixos.sops-install-secrets`) into `/run/secrets.d/`, symlinked from
`/run/secrets/<name>` — or from a per-secret `path` (used to land ssh config
in `$HOME`, see the
[private ssh hosts decision](../decisions/ssh-private-hosts.md)). Declared
secrets are validated at build time against their sops file, so declaring a
key before it exists in the file breaks the build (verified 2026-07-10).

Consumers today: [host k](../hosts/k.md) (smoke-test secret) and the
[ssh-private-hosts twins](ssh-private-hosts.md) (shared
`modules/hosts/ssh-hosts.yaml`, k + nebula recipients). [mini](../hosts/mini.md)
is a recipient for its own `secrets.yaml`, which holds
[git-signing-agent](git-signing-agent.md)'s service-account token, and its
separate `ssh-client.yaml` holds the [machine SSH identity](mini-ssh-client.md).
The signing token remains root-only; the SSH private key is deployed as
user `k`, mode `0400`, through a custom secret path.[^sops-nix]
[k](ssh-client.md) and [nebula](nebula-ssh-client.md) now have separate
client-key files encrypted to their own existing recipients as well.
Auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/sops.nix`](../../modules/darwin/sops.nix)

[^sops-nix]: Per-secret `owner`, `mode`, and `path` control the deployed secret and its symlink.
