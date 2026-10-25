---
type: Dual Module
title: Nh
description: 'nh (Nix Helper) plus the nrs/nrb/nrt rebuild helper executables (writeShellScriptBin, so they work in non-interactive shells and every shell alike).'
resource: modules/darwin/nh.nix
tags: [darwin-module, nixos-module]
generated: { by: okflight/0.4.0, at: 2026-07-03T12:00:00-07:00 }
---

nh (Nix Helper) — installs the package plus the rebuild helpers as real
executables (not shell aliases, which only exist in interactive shells). The
nh-backed helpers (`nrs`/`nrb` on darwin; all three on nixos) export
`NH_NO_CHECKS=1` and pass extra arguments through to nh; darwin's `nrt`
bypasses nh entirely, passing its arguments to `darwin-rebuild check`.
`NH_NO_CHECKS` only skips nh's two startup probes of the system Nix (nh
4.4.2, `crates/nh-core/src/checks.rs`): a version check that only warns
(minimum 2.31.2), and the nix-command/flakes feature check. Both always
pass here (Determinate Nix 2.35.3), so skipping them saves two `nix`
subprocesses. nh never runs the flake's checks; the old comment that said
it did was wrong (corrected 2026-10-24).

- **darwin** (nix-darwin has no programs.nh module): `nrs` (nh darwin
  switch), `nrb` (nh darwin build, no root), and `nrt` (darwin-rebuild
  check — the old `test` subcommand no longer exists in nh or
  darwin-rebuild). Flake dir is the literal `$HOME/src/dotfiles`.
- **nixos**: `nrs` (nh os switch), `nrb` (nh os build), and `nrt` (nh os
  test — activate without a bootloader entry, real test semantics unlike
  darwin's check). Flake dir resolved via `readlink -f "$HOME/src/dotfiles"`
  because nix's `--flake <path>` won't follow nebula's symlinked checkout.
  After a successful `nrs`/`nrt`, the helper compares the glibc that
  linux-pam links against in `/run/booted-system` with the one in
  `/run/current-system`. If they differ, it warns you to reboot before
  logging out: ly, started at boot, can't load the new PAM session modules
  (see [users-k-noctalia](users-k-noctalia.md)).

Package lists in sync (nh + three helpers each); see the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

[nrs2](nrs2.md) prototypes an nh-free replacement for `nrs` on both OSes. It streams the activation output, which nh 4.4.2 captures, and on NixOS it also runs activation as a transient systemd unit.

## Source

- darwin module: [`modules/darwin/nh.nix`](../../modules/darwin/nh.nix)
- NixOS module: [`modules/nixos/nh.nix`](../../modules/nixos/nh.nix)
