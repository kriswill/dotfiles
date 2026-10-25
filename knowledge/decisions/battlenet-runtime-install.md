---
type: Decision
title: Install Battle.net at First Run, Not Through Nix
description: 'The battlenet sub-flake packages only the runtime (GE-Proton, an FHS environment, a launcher) and installs Battle.net into a user-owned prefix on first run from Blizzard''s unpinned installer URL, because the installer is unpinnable and Battle.net replaces itself; Proton runs directly in steam.buildRuntimeEnv instead of through umu.'
tags: [battlenet, proton, wine, gaming]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-25T14:00:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/battlenet/README.md
    title: 'flakes/battlenet/README.md (how it runs, first run from nothing)'
  - id: faugus-launcher
    resource: https://github.com/Faugus/faugus-launcher/blob/main/faugus/launcher.py
    title: 'Faugus Launcher `launcher.py` (its Battle.net installer URL, flags and environment)'
  - id: steam-package
    resource: https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/st/steam/package.nix
    title: 'nixpkgs `steam` package (`buildRuntimeEnv`)'
  - id: ge-proton-readme
    resource: https://github.com/GloriousEggroll/proton-ge-custom
    title: 'GE-Proton (proton-ge-custom) README'
---

**Where:** [battlenet sub-flake](../packages/battlenet.md),
[battlenet module](../modules/battlenet.md).

## Context

Battle.net on nebula started as a hand-written umu `.desktop` file pointing at
a Steam-created prefix. Making it a reusable `programs.battlenet` module meant
deciding three things: what Nix owns, where Battle.net comes from, and what
runs Proton.

`https://downloader.battle.net/download/getInstaller?os=win&installer=Battle.net-Setup.exe`
redirects to the current versioned build. On 2026-10-25 that was
`installer/win/1.0.68/Battle.net-Setup.exe` (4.7 MB, modified 2026-10-20). The
installer only bootstraps: it downloads the Battle.net app, and the app updates
itself. Faugus Launcher runs this same URL with
`--installpath='C:\Program Files (x86)\Battle.net' --lang=enUS` and
`WINE_SIMULATE_WRITECOPY=1`.[^faugus-launcher]

## Decision

- **Nix owns the runtime only.** That is GE-Proton (`proton-ge-bin`), an FHS
  environment, and the launcher script. Battle.net, its registry and its
  games live in a user-owned compat data directory (`programs.battlenet.prefix`,
  default `~/Games/battlenet`), which Proton creates on first use.
- **The installer downloads at first run** into `~/.cache/battlenet/`. It is
  not a fixed-output derivation: the redirecting URL always serves the newest
  build, so a pinned hash would go stale; the content is unfree and not
  cacheable; and pinning a bootstrapper doesn't pin the self-updating app it
  installs. The launcher passes the same flags as Faugus. It sets
  `STORE=battlenet` instead of `WINE_SIMULATE_WRITECOPY=1`, because GE-Proton
  turns write-copy on itself for that store.
- **Proton runs directly** inside `steam.buildRuntimeEnv`, the free FHS
  builder behind `steam-run`.[^steam-package] umu-launcher and Valve's
  pressure-vessel container are not involved. The prefix uses Proton's own
  layout (`<compat>/pfx`). An umu prefix still works through the `pfx -> .`
  link umu leaves in it.[^subflake-readme]

## Consequences

A fresh host needs only `programs.battlenet.enable = true` and a first launch.
Nothing Blizzard ships is in the store, and nixpkgs' GE-Proton bumps reach the
prefix as in-place upgrades. The cost is that the first run needs the network,
and the install isn't reproducible: what gets installed is whatever Blizzard
serves that day. GE-Proton supports only umu for non-Steam games outside
Steam,[^ge-proton-readme] so problems on this route can't be reported
upstream. Nebula kept the stowed umu entry as a fallback at first, then dropped
umu-launcher and that entry on 2026-10-25, once the launcher had its
wineserver guard and Ctrl-C handling ([one wineserver](battlenet-one-wineserver.md)).

[^subflake-readme]: `flakes/battlenet/README.md`: how it runs, and first run from nothing
[^faugus-launcher]: Faugus Launcher `launcher.py`, `download_launcher()` (the "battle" branch)
[^steam-package]: nixpkgs `steam` package: `buildRuntimeEnv`
[^ge-proton-readme]: GE-Proton README: "Running non-Steam games with GE-Proton outside of Steam is only supported using umu"
