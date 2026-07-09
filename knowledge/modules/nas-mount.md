---
type: Darwin Module
title: Nas Mount
description: 'Auto-mount the UNAS Pro 4''s Personal-Drive SMB share at login via a launchd user agent.'
resource: modules/darwin/nas-mount.nix
tags: [darwin-module]
timestamp: '2026-07-09T17:56:49+00:00'
---

Auto-mounts the UNAS Pro 4's Personal-Drive SMB share at `~/nas` at login via
a `launchd.user.agents.nas-mount` job (`RunAtLoad` + `StartInterval = 300` to
retry if the NAS/network wasn't up yet). Full backstory — how `nas.home.lan`
was created as a UniFi "Local DNS Record" (not a static DNS entry), and why
mounting via it conflicts with the pre-existing Bonjour-based mount (macOS
treats both hostnames as the same negotiated server identity and refuses a
second concurrent mount) — is in
[docs/unifi-dream-machine.md](../../docs/unifi-dream-machine.md).

**`-N` (keychain-only auth) is load-bearing, not cosmetic**: a launchd agent
has no session to show an interactive password sheet, so the job only works
because macOS already resolves a matching keychain entry for this server —
confirmed the same entry serves both the Bonjour and DNS hostnames. The mount
script is idempotent (`mount | grep` guard) so `RunAtLoad` firing against an
already-mounted share is a harmless no-op.

Imported on every darwin host but disabled by default — hosts opt in with
`services.nas-mount.enable = true;`
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)):
enabled on [k](../hosts/k.md), deliberately not on mini or SOC-Kris-Williams
(personal NAS, personal machine); auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/nas-mount.nix`](../../modules/darwin/nas-mount.nix)
- Options under: `services.nas-mount`
