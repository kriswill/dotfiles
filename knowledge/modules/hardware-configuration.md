---
type: Darwin Module
title: Hardware Configuration
description: 'DENDRITIC WRAPPER: the generated module body is held under `configurations.nixos.nebula.module` so this file is a valid flake-parts module (every `.nix` under modules/ is auto-imported as one).'
resource: modules/hosts/nebula/hardware-configuration.nix
tags: [darwin-module, host-specific]
timestamp: '2026-06-14T16:34:25-07:00'
---

DENDRITIC WRAPPER: the generated module body is held under `configurations.nixos.nebula.module` so this file is a valid flake-parts module (every `.nix` under modules/ is auto-imported as one). If you ever regenerate this with `nixos-generate-config`, re-apply this two-line wrapper around the raw output, or flake-parts evaluation will fail on the bare NixOS module.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/hardware-configuration.nix`](../../modules/hosts/nebula/hardware-configuration.nix)
