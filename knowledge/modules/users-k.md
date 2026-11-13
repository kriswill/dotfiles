---
type: NixOS Module
title: Users K
description: 'Defines nebula user k with a sops-managed password, personal and managed-machine SSH keys, wheel/networkmanager/libvirtd groups, and a user-default flatpak wrapper.'
resource: modules/hosts/nebula/users/k/default.nix
tags: [nixos-module, host-specific]
generated: { by: codex/gpt-6, at: 2026-11-13T11:54:45-08:00 }
sources:
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix secret provisioning
---

Defines user `k`. The password comes from sops: `sops.secrets.k_password`
with `neededForUsers = true` (decrypted early enough for user creation),[^sops-nix]
consumed via `users.users.k.hashedPasswordFile`. The authorized SSH key is
pulled from snowglobe's keyring (`config.keyring.ssh.k`), supplemented by
the machine public keys of [k](ssh-client.md), [mini](mini-ssh-client.md),
and [nebula](nebula-ssh-client.md). The common
[list](../../lib/ssh-machines.nix) feeds `authorizedKeys.keyFiles`, also
used by [darwin core](core.md).
Groups: `wheel`,
`networkmanager`, `libvirtd` — the `i2c` group is added separately by
[users-k-desktop-shell](users-k-desktop-shell.md) for DDC/CI brightness.

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

[^sops-nix]: `neededForUsers` decrypts password secrets before user creation.
