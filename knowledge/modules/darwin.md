---
type: Flake-parts Module
title: Darwin
description: Declares `configurations.darwin.<name>` and realises each into a `darwinConfigurations.<name>` flake output (plus a toplevel build check).
resource: modules/darwin.nix
tags: [flake-parts]
timestamp: '2026-05-24T19:25:21-07:00'
---

Declares `configurations.darwin.<name>` and realises each into a `darwinConfigurations.<name>` flake output (plus a toplevel build check). Adapted from the mightyiam/dendritic example `nixos.nix`.

Plumbing layer of the flake — see the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin.nix`](../../modules/darwin.nix)
