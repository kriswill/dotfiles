---
type: NixOS Module
title: Herdr Update Check
description: Daily reminder to drop the herdr preview-flake pin (flake.nix) once nixos-unstable ships a herdr newer than the 0.7.5 the pin shadows — see docs/fastfetch.md.
resource: modules/hosts/nebula/herdr-update-check.nix
tags: [nixos-module, host-specific]
timestamp: '2026-08-02T22:35:36-07:00'
---

Daily reminder to drop the herdr preview-flake pin (flake.nix) once nixos-unstable ships a herdr newer than the 0.7.5 the pin shadows — see docs/fastfetch.md. One raw-file HTTP fetch, no nix eval. Pops a dismissable critical notification; clicking the action opens the upstream releases page. DELETE THIS FILE together with the pin.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/herdr-update-check.nix`](../../modules/hosts/nebula/herdr-update-check.nix)
