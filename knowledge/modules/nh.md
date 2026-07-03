---
type: Darwin Module
title: Nh
description: nh (Nix Helper) — installs the package behind the nrs/nrt rebuild aliases in core.nix.
resource: modules/darwin/nh.nix
tags: [darwin-module]
timestamp: '2026-05-24T22:21:04-07:00'
---

nh (Nix Helper) — nix-darwin has no programs.nh module, so this just installs
the package; the `nrs`/`nrt` rebuild aliases in [core](core.md) invoke it via
`lib.getExe`.

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/nh.nix`](../../modules/darwin/nh.nix)
