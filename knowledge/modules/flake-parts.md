---
type: Flake-parts Module
title: Flake Parts
description: Top-level flake-parts wiring for the Dendritic pattern.
resource: modules/flake-parts.nix
tags: [flake-parts]
timestamp: '2026-05-24T19:25:21-07:00'
---

Top-level flake-parts wiring for the Dendritic pattern. `flakeModules.modules` provides the `flake.modules.<class>.<name>` option (<https://flake.parts/options/flake-parts-modules.html>) into which every feature file merges its darwin / home-manager module.

Plumbing layer of the flake — see the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/flake-parts.nix`](../../modules/flake-parts.nix)
