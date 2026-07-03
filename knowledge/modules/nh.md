---
type: Darwin Module
title: Nh
description: nh (Nix Helper) plus the nrs/nrb/nrt rebuild helper executables (writeShellScriptBin, so they work in non-interactive shells and every shell alike).
resource: modules/darwin/nh.nix
tags: [darwin-module]
timestamp: '2026-05-24T22:21:04-07:00'
---

nh (Nix Helper) — nix-darwin has no programs.nh module, so this installs the
package plus the rebuild helpers as real executables (not shell aliases, which
only exist in interactive shells): `nrs` (nh darwin switch), `nrb` (nh darwin
build, no root), and `nrt` (darwin-rebuild check — the old `test` subcommand
no longer exists in nh or darwin-rebuild).

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/nh.nix`](../../modules/darwin/nh.nix)
