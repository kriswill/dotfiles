---
type: NixOS Module
title: Hardware Configuration
description: 'nixos-generate-config output in the two-line dendritic wrapper: initrd kernel modules, kvm-amd, x86_64-linux hostPlatform, and AMD microcode updates.'
resource: modules/hosts/nebula/hardware-configuration.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

DENDRITIC WRAPPER: the generated module body is held under
`configurations.nixos.nebula.module` so this file is a valid flake-parts
module (every `.nix` under modules/ is auto-imported as one). If you ever
regenerate this with `nixos-generate-config`, re-apply this two-line wrapper
around the raw output, or flake-parts evaluation will fail on the bare NixOS
module.

The generated contents: initrd kernel modules (nvme, xhci_pci, ahci,
thunderbolt, usb_storage, usbhid, sd_mod), `kvm-amd`,
`nixpkgs.hostPlatform = "x86_64-linux"` (mkDefault), and AMD microcode
updates tied to `enableRedistributableFirmware`.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/hardware-configuration.nix`](../../modules/hosts/nebula/hardware-configuration.nix)
