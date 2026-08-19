---
type: Flake-parts Module
title: Nixos
description: 'Declares `configurations.nixos.<name>` and realises each into a `nixosConfigurations.<name>` flake output (plus a toplevel build check), building through snowglobe-factory''s `mkNixosHost` so all the `snowglobe-factory.profiles.*` / `snowglobe-factory.desktop.*` machinery and the hardware wiring are still applied.'
resource: modules/nixos.nix
tags: [flake-parts]
timestamp: '2026-06-14T15:52:26-07:00'
---

Declares `configurations.nixos.<name>` and realises each into a `nixosConfigurations.<name>` flake output (plus a toplevel build check), building through snowglobe-factory's `mkNixosHost` so all the `snowglobe-factory.profiles.*` / `snowglobe-factory.desktop.*` machinery and the hardware wiring are still applied. Adapted from main's `modules/darwin.nix`.

Plumbing layer of the flake — see the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos.nix`](../../modules/nixos.nix)
