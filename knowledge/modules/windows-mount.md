---
type: NixOS Module
title: Windows Mount
description: Permanent read-only ntfs-3g mount of the Windows NTFS partition (the other NVMe) at /mnt/windows — lazy systemd automount with nofail; read-only tolerates Fast-Startup-"dirty" volumes.
resource: modules/hosts/nebula/windows-mount.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

Permanent **read-only** ntfs-3g mount of the Windows NTFS partition on the
other NVMe (`/dev/disk/by-uuid/902A59752A5958F4`, nvme1n1p3) at
`/mnt/windows`. `boot.supportedFilesystems = ["ntfs"]` pulls in the ntfs-3g
userspace driver; mount options set `uid=1000`/`gid=100`/`umask=022`,
`windows_names`, `nofail` (boot proceeds if the disk is absent), and
`x-systemd.automount` with a 5s device timeout, so the volume mounts lazily
on first access.

Read-only is deliberate: it avoids any corruption risk and still mounts a
volume left "dirty" by Windows Fast Startup / hibernation — good enough for
copying files off Windows. Go read-write only after disabling Fast Startup in
Windows. (This is the same Windows install that drives the GRUB os-prober
dual-boot decision in [configuration](configuration.md).)

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/windows-mount.nix`](../../modules/hosts/nebula/windows-mount.nix)
