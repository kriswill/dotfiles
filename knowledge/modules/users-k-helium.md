---
type: NixOS Module
title: Users K Helium
description: Installs pkgs.helium-config for user k — the snapshot/restore CLI that syncs Helium's user settings into config/helium/ without symlinking the live Chromium profile.
resource: modules/hosts/nebula/users/k/helium.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

Installs `pkgs.helium-config` in `users.users.k.packages` — the
snapshot/restore CLI for Helium's user settings (Bookmarks + its `.bak`,
Preferences, Local State, Cookies, Login Data) into the dotfiles repo
(`config/helium/`) WITHOUT symlinking the live profile.

Why not stow: Helium (Chromium) saves via atomic rename, which would break —
and on the next restow clobber — a stowed profile; the full rationale and the
capture/restore/diff CLI shape live in the
[snapshot-synced configs pattern](../patterns/snapshot-synced-configs.md).
Helium is the pattern's only age-encrypted instance — its snapshots include
live credential stores (`Cookies`, `Login Data`), so every captured file is
age-encrypted at rest and the public repo holds only ciphertext. Same pattern
as [users-k-noctalia](users-k-noctalia.md)'s noctalia-config.

The system-level Helium config (browser enable + managed policies) lives in
`modules/nixos/helium/`, not here. The CLI itself is defined in
`pkgs/helium-config.nix`.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/users/k/helium.nix`](../../modules/hosts/nebula/users/k/helium.nix)
- Manual: [`docs/helium.md`](../../docs/helium.md)
