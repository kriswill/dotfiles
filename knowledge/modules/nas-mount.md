---
type: NixOS Module
title: Nas Mount
description: 'On-demand SMB mount of the UNAS-PRO (192.168.0.82) personal drive''s backups/wowdps-journal folder: the destination for the wowdps-suite coordinator''s daily journal snapshots (the live SQLite journal stays on local disk and is never opened over SMB).'
resource: modules/hosts/nebula/nas-mount.nix
tags: [nixos-module, host-specific]
generated: { by: okflight/0.5.0, at: 2026-11-23T05:28:07+00:00 }
---

On-demand SMB mount of the UNAS-PRO (192.168.0.82) personal drive's backups/wowdps-journal folder: the destination for the wowdps-suite coordinator's daily journal snapshots (the live SQLite journal stays on local disk and is never opened over SMB). Owner-only (k, 0600/0700): the snapshots include a private prompt log and the backup tool refuses a destination others can read. With no SMB unix extensions, these client-side modes are what the kernel enforces. Automount + nofail + short timeouts: nothing touches the NAS until the path is first accessed, a NAS that is down only fails that access (never boot or a login), and the mount drops after idling. Credentials: the `nas-smb-credentials` sops key in secrets.yaml is a cifs credentials file (username=/password= lines), written from the 1Password item "UNAS-PRO (k)". sops-nix decrypts it root-only; mount.cifs runs as root.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/nas-mount.nix`](../../modules/hosts/nebula/nas-mount.nix)
