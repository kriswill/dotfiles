---
type: NixOS Module
title: Users K
description: Defines user k — sops-managed password (neededForUsers), authorized SSH key from snowglobe's keyring, wheel/networkmanager/libvirtd groups, and pkgs.flatpak-user shadowing the system flatpak via PATH.
resource: modules/hosts/nebula/users/k/default.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

Defines user `k`. The password comes from sops: `sops.secrets.k_password`
with `neededForUsers = true` (decrypted early enough for user creation),
consumed via `users.users.k.hashedPasswordFile`. The authorized SSH key is
pulled from snowglobe's keyring (`config.keyring.ssh.k`). Groups: `wheel`,
`networkmanager`, `libvirtd` — the `i2c` group is added separately by
[users-k-noctalia](users-k-noctalia.md) for DDC/CI brightness.

Also installs `pkgs.flatpak-user` in `users.users.k.packages`: a flatpak CLI
wrapper defaulted to `--user`, which shadows the system flatpak because the
per-user profile sits ahead on PATH. Pairs with
[flatpak-repo-user](flatpak-repo-user.md), which registers Flathub in the
per-user installation at login.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/users/k/default.nix`](../../modules/hosts/nebula/users/k/default.nix)
