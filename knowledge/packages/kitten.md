---
type: Nix Package
title: Kitten
description: Kitten - A collection of small, useful programs for the kitty terminal.
resource: pkgs/kitten.nix
tags: [package]
timestamp: '2025-08-06T17:06:42-07:00'
---

Kitten - A collection of small, useful programs for the kitty terminal.

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/kitten.nix`](../../pkgs/kitten.nix)
- Version at last scaffold: `0.42.2`
- Overlay: [`overlays/kitten.nix`](../../overlays/kitten.nix) — exposes/replaces `pkgs.kitten`

## Notes

- Prebuilt static binary for **both** aarch64-darwin and linux-amd64 (per-platform
  `fetchurl` keyed on `stdenv.hostPlatform.system`). On nebula it exists solely so
  fastfetch's `kitty-icat` logo can shell out to it (`docs/fastfetch.md`) — the full
  `kitty` package was dropped from nebula in `907cf90`, which silently broke the logo.
