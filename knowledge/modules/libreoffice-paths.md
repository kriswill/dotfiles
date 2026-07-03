---
type: NixOS Module
title: Libreoffice Paths
description: 'Moves LibreOffice''s user-writable paths out of ~/.config/libreoffice into XDG data/state dirs by seeding both the modern and legacy path nodes into registrymodifications.xcu — idempotent, skip-if-running, subshell-confined.'
resource: modules/nixos/libreoffice-paths.nix
tags: [nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Redirects LibreOffice's user-writable paths (Backup, AutoCorrect, AutoText,
Gallery, Template, Dictionary, Graphic, DocumentTheme) out of
`~/.config/libreoffice/4/user` into XDG data/state dirs. The trick — derived
from reading LO's `pathsettings.cxx` — is seeding **both** the modern
`org.openoffice.Office.Paths` WritePath/UserPaths nodes **and** the legacy
`Common/Path/Current` nodes into `registrymodifications.xcu`, set equal so
`impl_mergeOldUserPaths` skips the legacy values instead of clobbering the
new ones.

Mechanics: tmpfiles pre-create the 8 target dirs; an activation script with
`deps = ["users"]` seeds idempotently (sentinel: `NamedPath['Backup']`),
skips when `soffice.bin` is running (LO rewrites the file on exit), and
either creates a minimal file for a fresh profile or awk-inserts before
`</oor:items>`. The whole script is confined to a subshell so `exit`/`set -u`
can't abort the rest of NixOS's single concatenated activation script — the
footgun behind the June-06 unbootable generations (manual below).

Mounted ungated on every NixOS host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/libreoffice-paths.nix`](../../modules/nixos/libreoffice-paths.nix)
- Manual: [`docs/libreoffice.md`](../../docs/libreoffice.md)
- Manual: [`docs/bootloader-issues-jun-06.md`](../../docs/bootloader-issues-jun-06.md)
