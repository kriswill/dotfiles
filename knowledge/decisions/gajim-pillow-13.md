---
type: Decision
title: Build Gajim Against Pillow 13 Until nixpkgs Ships It
description: 'nebula builds only Gajim against Pillow 13.0.0, because nixpkgs'' 12.3.0 has 39 advisories (five critical) fixed only in 13.0.0 and Gajim decodes images from the network; dropping CUPS and Thunderbird left Gajim as the only runtime user, so a 3-derivation override replaces a 52-derivation global overlay, and it throws once nixpkgs catches up.'
tags: [nixploit, cve, pillow, gajim]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-26T18:05:00-07:00 }
sources:
  - id: ghsa-96639
    resource: https://github.com/advisories/GHSA-v9pv-5gc8-w2m6
    title: 'GHSA-v9pv-5gc8-w2m6 / CVE-2026-96639: Pillow multi-frame loaders reuse stale native image storage (critical, patched in 13.0.0)'
  - id: pillow-13
    resource: https://pillow.readthedocs.io/en/stable/releasenotes/13.0.0.html
    title: 'Pillow 13.0.0 release notes (security fixes, backwards-incompatible changes)'
  - id: nixpkgs-bump
    resource: https://github.com/NixOS/nixpkgs/commit/084270a6626c
    title: 'nixpkgs 084270a: python3Packages.pillow 12.3.0 -> 13.0.0 (staging)'
---

**Where:** [configuration](../modules/configuration.md)
(`programs.gajim.package`) on [nebula](../hosts/nebula.md); found by
[nebula-nixploit](../modules/nebula-nixploit.md).

## Context

nixploit flagged Pillow 12.3.0 with 39 advisories. Five are critical: a 9.8
for multi-frame loaders reusing freed image storage,[^ghsa-96639] and four
9.2s (heap overflows in JPEG, FlashPix and TIFF handling, and argument
injection into Ghostscript). All are fixed in Pillow 13.0.0, released
2026-10-16, and there is no 12.x release with the fixes.[^pillow-13] nixpkgs
has the bump on `staging` only (`084270a`, 2026-10-18), a plain version and
hash change, so it is probably one to three weeks from
`nixos-unstable`.[^nixpkgs-bump]

Gajim is the exposed consumer. It opens images with `Image.open` and every
format enabled: thumbnails of received files, avatars, animated images, and
the OpenGraph images it downloads for link previews. hplip also kept 12.3.0
installed, through reportlab.

## Decision

1. Drop what we don't use. `snowglobe-factory.cups.enable = false` removes
   CUPS, the office profile's six printer drivers (hplip among them) and the
   Avahi daemon that module turns on. No printers were configured, and
   nothing on nebula used `.local` names. `programs.thunderbird.enable =
   false` removes Thunderbird, which was also unused.
2. Build Gajim against a `python3.override { packageOverrides = …; }` whose
   `pillow` is 13.0.0, with the same source and hash as the nixpkgs bump.
   That rebuilds three derivations: pillow, qrcode and gajim.
3. Guard it with `lib.versionOlder` on nixpkgs' Pillow. Once nixpkgs ships
   13.0.0 or later, evaluation throws and says to remove the override, so it
   can't linger as dead code.

None of the four consumers (Gajim, lutris, reportlab, hplip) use an API that
13.0.0 removed.[^pillow-13] The override passed Pillow's test suite (5627)
and Gajim's (106), and on 2026-10-26 a smoke test ran Gajim's link-preview
thumbnailer and `extract_frames` (on a 4-frame GIF) under 13.0.0. In the
built system Pillow went from 12.3.0 to 13.0.0, and 12.3.0 left the closure.

Rejected:

- **A global `pythonPackagesExtensions` overlay.** It is the cleaner fix in
  principle, but every package with Pillow anywhere in its build graph
  rebuilds locally. That was 56 derivations, including Thunderbird and
  onnxruntime (Thunderbird → onnxruntime → onnx → pillow). After Thunderbird
  was dropped it was still 52: kitty, matplotlib, hplip, the Noto emoji
  font, Steam's FHS roots. Overlays also reach the Macs, where the cost
  wasn't measured.
- **Waiting for nixpkgs.** That would leave a network-reachable decoder
  vulnerable for one to three weeks.

## Consequences

Other Python packages still use nixpkgs' Pillow 12.3.0 while building
(kitty, matplotlib, nototools). That isn't in the runtime closure, and
nixploit doesn't scan build dependencies. If something new starts pulling
Pillow at runtime, nixploit reports 12.3.0 again, and the choice between
another targeted override and the global overlay comes back.

Losing Avahi loses mDNS: the NAS is still `unas-pro.home.lan` or
`nas.home.lan` through the router, but file-manager network browsing no
longer discovers it on its own. Landed in commit `0e94360`.

[^ghsa-96639]: GHSA-v9pv-5gc8-w2m6 / CVE-2026-96639: Pillow multi-frame loaders reuse stale native image storage (critical, patched in 13.0.0)
[^pillow-13]: Pillow 13.0.0 release notes (security fixes, backwards-incompatible changes)
[^nixpkgs-bump]: nixpkgs 084270a: python3Packages.pillow 12.3.0 -> 13.0.0 (staging)
