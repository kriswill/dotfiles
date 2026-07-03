---
type: NixOS Module
title: Disko
description: Declarative disko layout for the NixOS NVMe — GPT with a 1M bios-boot partition, a 512M vfat ESP at /boot, and an unencrypted ext4 root filling the rest.
resource: modules/hosts/nebula/disko.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

Declarative disko layout for the NixOS NVMe
(`/dev/disk/by-id/nvme-eui.002538a26141bda4`): a GPT disk with a 1M `EF02`
bios-boot partition (lets legacy/CSM-mode GRUB boot a GPT drive), a 512M vfat
ESP mounted at `/boot` (`umask=0077` to silence the world-readable-keys
warning), and an **unencrypted ext4 root** filling the rest of the disk.

The unencrypted root is a load-bearing fact: it is the security rationale for
`boot.initrd.systemd.emergencyAccess = true` in
[configuration](configuration.md) — anyone with physical access already has
full data access, so a passwordless initrd rescue shell doesn't widen the
threat model.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/disko.nix`](../../modules/hosts/nebula/disko.nix)
