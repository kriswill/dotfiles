---
type: Darwin Module
title: Sops
description: sops-nix on macOS — universal machinery, inert until a host defines secrets.
resource: modules/darwin/sops.nix
tags: [darwin-module]
timestamp: '2026-07-03T12:58:16-07:00'
---

sops-nix on macOS — universal machinery, inert until a host defines secrets. The age identity is derived from the host's SSH host key (ssh-to-age), so no new key material is managed: each Mac's recipient comes from ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub and is registered in .sops.yaml. A host that wants secrets adds sops.defaultSopsFile = ./secrets.yaml; # in modules/hosts/<host>/ sops.secrets.<name> = { }; plus a matching creation rule in .sops.yaml (edit with `sops modules/hosts/<host>/secrets.yaml`; sops/age/ssh-to-age are in the dev shell). Mirrors nebula's setup (modules/hosts/nebula.nix), which gets the sops module via snowglobe-lib's mkNixosHost instead.

Re-exports a module whose options ship with the re-exported flake —
disabled by default; hosts opt in via its enable option (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)); auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/sops.nix`](../../modules/darwin/sops.nix)
