---
type: Darwin Module
title: Apple Container
description: apple-container ships its nix-darwin module with its sub-flake (./flakes/apple-container/darwin-module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module.
resource: modules/darwin/apple-container.nix
tags: [darwin-module]
timestamp: '2026-06-11T07:14:49-07:00'
---

apple-container ships its nix-darwin module with its sub-flake (./flakes/apple-container/darwin-module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module. The module defaults kriswill.apple-container.package to the sub-flake's own package, so no overlay or pkgs wiring is needed.

Follows the [module option pattern](../patterns/module-option-pattern.md), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/apple-container.nix`](../../modules/darwin/apple-container.nix)
