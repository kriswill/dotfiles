---
type: Dual Module
title: Iv
description: iv — command-line image viewer using terminal graphics (kitty/sixel).
resource: modules/darwin/iv.nix
tags: [darwin-module, nixos-module]
generated: { by: okflight/0.4.0, at: 2026-09-14T01:07:43+00:00 }
---

iv — command-line image viewer using terminal graphics (kitty/sixel). Derivation in pkgs/iv.nix, exposed as pkgs.iv via the iv overlay.

Mounted ungated on every host of both classes
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).
A cross-OS twin — parallel implementations in each class dir (see the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md)).

## Source

- darwin module: [`modules/darwin/iv.nix`](../../modules/darwin/iv.nix)
- NixOS module: [`modules/nixos/iv.nix`](../../modules/nixos/iv.nix)
