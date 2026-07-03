---
type: NixOS Module
title: Keyring
description: 'snowglobe-lib installer key metadata (NOT GNOME Keyring) — user k''s ssh-ed25519 public key and nebula''s age recipient; do not remove.'
resource: modules/nixos/keyring.nix
tags: [nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Despite the name, this is **not** GNOME Keyring. It declares the
snowglobe-lib `keyring` option set consumed by the installer: user `k`'s
ssh-ed25519 public key, nebula's age recipient (`age1gduheq…`), and an empty
`openpgp` set. The header warns "do not remove — used by the installer to
manage and reference your keys": it installs no packages and has no runtime
effect beyond what snowglobe-lib derives from it.

The age recipient here is the same identity that appears in
[`.sops.yaml`](../../.sops.yaml)'s recipients (derived from nebula's SSH host
key via `ssh-to-age`) — the [sops](sops.md) secrets story and this installer
metadata must stay consistent.

Mounted ungated on every NixOS host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/keyring.nix`](../../modules/nixos/keyring.nix)
