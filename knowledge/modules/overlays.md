---
type: Flake-parts Module
title: Overlays
description: Nixpkgs overlays, exposed as flake outputs and consumed by the host modules via `nixpkgs.overlays = builtins.attrValues config.flake.overlays`.
resource: modules/overlays.nix
tags: [flake-parts]
timestamp: '2026-06-30T23:08:15-07:00'
---

Nixpkgs overlays, exposed as flake outputs and consumed by the host modules via `nixpkgs.overlays = builtins.attrValues config.flake.overlays`.

Plumbing layer of the flake — see the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/overlays.nix`](../../modules/overlays.nix)
