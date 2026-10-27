---
type: NixOS Module
title: Gajim Pillow
description: 'Builds nebula''s Gajim against Pillow 13.0.0 (39 advisories fixed over nixpkgs'' 12.3.0) through a Gajim-only python3 override, until nixpkgs ships 13.0.0; then it falls back to stock Gajim and warns.'
resource: modules/hosts/nebula/gajim-pillow.nix
tags: [nixos-module, host-specific, cve]
generated: { by: claude-code/opus-5.5, at: 2026-10-26T18:50:00-07:00 }
sources:
  - id: ghsa-96639
    resource: https://github.com/advisories/GHSA-v9pv-5gc8-w2m6
    title: 'GHSA-v9pv-5gc8-w2m6 / CVE-2026-96639: Pillow multi-frame loaders reuse stale native image storage'
---

Sets `programs.gajim.package` (snowglobe's Gajim module, enabled in
[configuration](configuration.md)) to Gajim built against a
`python3.override` whose `pillow` is 13.0.0. Gajim decodes images from the
network with Pillow, and 12.3.0 has 39 advisories, five critical, all fixed
only in 13.0.0.[^ghsa-96639] Only Gajim's Python changes, so three derivations
rebuild (pillow, qrcode, gajim). Why not a global overlay is in the
[decision](../decisions/gajim-pillow-13.md).

`needed` compares nixpkgs' own Pillow version with 13.0.0. Once nixpkgs
ships it, `programs.gajim.package` is left at its default (stock Gajim) and
a NixOS warning names the file to delete. [brotli-graft](brotli-graft.md)
retires the same way.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/gajim-pillow.nix`](../../modules/hosts/nebula/gajim-pillow.nix)

[^ghsa-96639]: GHSA-v9pv-5gc8-w2m6 / CVE-2026-96639: Pillow multi-frame loaders reuse stale native image storage
