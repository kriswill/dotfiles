---
type: NixOS Module
title: Herdr Update Check
description: Daily reminder to drop the herdr upstream-flake pin (flake.nix) once nixos-unstable ships a herdr >= the pinned 0.8.0 — see docs/fastfetch.md.
resource: modules/hosts/nebula/herdr-update-check.nix
tags: [nixos-module, host-specific]
timestamp: '2026-08-02T22:35:36-07:00'
---

Daily reminder to drop the herdr upstream-flake pin (flake.nix) once nixos-unstable ships a herdr >= the pinned 0.8.0 (equality included — nixpkgs landing exactly the pinned version is the drop signal) — see docs/fastfetch.md. One raw-file HTTP fetch, no nix eval. Pops a dismissable critical notification; clicking the action opens the upstream releases page. DELETE THIS FILE together with the pin. The pin covers darwin too ([herdr](herdr.md) is a twin pair since 2026-08-03), so dropping it reverts both OSes.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/herdr-update-check.nix`](../../modules/hosts/nebula/herdr-update-check.nix)
