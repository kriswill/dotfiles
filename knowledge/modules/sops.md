---
type: Darwin Module
title: Sops
description: sops-nix on macOS — universal secrets machinery whose age identity derives from the host SSH key; inert until a host declares secrets.
resource: modules/darwin/sops.nix
tags: [darwin-module]
timestamp: '2026-07-11T12:40:00-07:00'
---

Imports `sops-nix.darwinModules.sops` on every darwin host and points
`sops.age.sshKeyPaths` at `/etc/ssh/ssh_host_ed25519_key`, so each Mac's age
identity derives from its SSH host key (`ssh-to-age`) — no new key material
to manage. Universal but inert: nothing happens until a host declares
`sops.defaultSopsFile` + `sops.secrets.<name>` and `.sops.yaml` gains the
matching recipient anchor + creation rule. Mirrors
[nebula](../hosts/nebula.md)'s setup, which gets the NixOS sops module via
snowglobe-lib's `mkNixosHost` instead.

Secrets install at activation through a launchd daemon
(`org.nixos.sops-install-secrets`) into `/run/secrets.d/`, symlinked from
`/run/secrets/<name>` — or from a per-secret `path` (used to land ssh config
in `$HOME`, see the
[private ssh hosts decision](../decisions/ssh-private-hosts.md)). Declared
secrets are validated at build time against their sops file, so declaring a
key before it exists in the file breaks the build (verified 2026-07-10).

Consumer today: [host k](../hosts/k.md) (smoke-test secret + the private ssh
hosts file). Auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Citations

- [sops-nix](https://github.com/Mic92/sops-nix) — darwin module, per-secret
  `owner`/`mode`/`path` options

## Source

- Module: [`modules/darwin/sops.nix`](../../modules/darwin/sops.nix)
