---
type: Darwin Module
title: Apple Container
description: apple-container ships its nix-darwin module with its sub-flake (./flakes/apple-container/darwin-module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module.
resource: modules/darwin/apple-container.nix
tags: [darwin-module]
timestamp: '2026-07-03T10:23:09-07:00'
---

apple-container ships its nix-darwin module with its sub-flake (./flakes/apple-container/darwin-module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module. The module defaults services.apple-container.package to the sub-flake's own package, so no overlay or pkgs wiring is needed. Enable per host with `services.apple-container.enable = true;`.

Imported on every darwin host but disabled by default — hosts opt in with
`services.apple-container.enable = true;` (the options live in the sub-flake's
darwin module; see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)); auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/apple-container.nix`](../../modules/darwin/apple-container.nix)
