---
type: Dual Module
title: Pass
description: 'Installs pass-xdg — a wrapper itself named `pass` that defaults PASSWORD_STORE_DIR to $XDG_DATA_HOME/password-store; never also install pkgs.pass or the two binaries collide.'
resource: modules/darwin/pass.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Installs `pkgs.pass-xdg` (from
[`pkgs/pass-xdg.nix`](../../pkgs/pass-xdg.nix) via its overlay) — a wrapper
whose binary is itself named `pass`, shadowing the plain password-store
binary and defaulting `PASSWORD_STORE_DIR` to
`$XDG_DATA_HOME/password-store` so the store stays out of `~/.password-store`.
Both twins encode the same warning: do **not** also add `pkgs.pass`, or two
`pass` binaries collide in the system profile. Decryption is backed by
gpg-agent from the [gpg](gpg.md) twin.

## Twin differences

None — the twins are byte-equivalent apart from comments, and package lists
are in sync (pass-xdg only, both). See the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/pass.nix`](../../modules/darwin/pass.nix)
- NixOS module: [`modules/nixos/pass.nix`](../../modules/nixos/pass.nix)
