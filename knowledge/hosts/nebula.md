---
type: Host
title: nebula
description: nebula — AMD CPU, NVIDIA GPU, UEFI desktop.
resource: modules/hosts/nebula.nix
tags: [host]
timestamp: '2026-06-19T21:33:40-07:00'
---

nebula — AMD CPU, NVIDIA GPU, UEFI desktop. Registers into the `configurations.nixos` registry (realised by `modules/nixos.nix` through snowglobe-lib's `mkNixosHost`). This file carries the host metadata and the shared baseline of its `module`; the host-specific pieces live as their own first-class dendritic files under `nebula/`, each a flake-parts module that merges into `configurations.nixos.nebula.module` (the realizer's `deferredModule` option), so there is no import-tree exclusion and no hand-maintained imports list. Non-`.nix` files (secrets.yaml, *.pub) sit in `nebula/` too — import-tree only picks up `.nix`, so they are ignored by the scan and referenced by path.

Imports every [darwin module](../modules/index.md); host-selective features
are opted into below per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Host-selective features

- [configuration](../modules/configuration.md) (host-specific file)
- [console-quiet](../modules/console-quiet.md) (host-specific file)
- [disko](../modules/disko.md) (host-specific file)
- [flatpak-repo-user](../modules/flatpak-repo-user.md) (host-specific file)
- [hardware-configuration](../modules/hardware-configuration.md) (host-specific file)
- [hyprland](../modules/hyprland.md) (host-specific file)
- [ly](../modules/ly.md) (host-specific file)
- [sudo-1password](../modules/sudo-1password.md) (host-specific file)
- [windows-mount](../modules/windows-mount.md) (host-specific file)

## Source

- Host module: [`modules/hosts/nebula.nix`](../../modules/hosts/nebula.nix)
