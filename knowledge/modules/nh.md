---
type: Dual Module
title: Nh
description: nh (Nix Helper) plus the nrs/nrb/nrt rebuild helper executables (writeShellScriptBin, so they work in non-interactive shells and every shell alike).
resource: modules/darwin/nh.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

nh (Nix Helper) — installs the package plus the rebuild helpers as real
executables (not shell aliases, which only exist in interactive shells). The
nh-backed helpers (`nrs`/`nrb` on darwin; all three on nixos) export
`NH_NO_CHECKS=1` (flake checks rebuild every host — too slow for an inner
loop) and pass extra arguments through to nh; darwin's `nrt` bypasses nh
entirely, passing its arguments to `darwin-rebuild check`.

- **darwin** (nix-darwin has no programs.nh module): `nrs` (nh darwin
  switch), `nrb` (nh darwin build, no root), and `nrt` (darwin-rebuild
  check — the old `test` subcommand no longer exists in nh or
  darwin-rebuild). Flake dir is the literal `$HOME/src/dotfiles`.
- **nixos**: `nrs` (nh os switch), `nrb` (nh os build), and `nrt` (nh os
  test — activate without a bootloader entry, real test semantics unlike
  darwin's check). Flake dir resolved via `readlink -f "$HOME/src/dotfiles"`
  because nix's `--flake <path>` won't follow nebula's symlinked checkout.

Package lists in sync (nh + three helpers each); see the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/nh.nix`](../../modules/darwin/nh.nix)
- NixOS module: [`modules/nixos/nh.nix`](../../modules/nixos/nh.nix)
