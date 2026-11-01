---
type: Decision
title: Pin Herdr's Core Lookup to herdr-core's Own bin
description: 'The herdr-app wrapper sets HERDR_CORE_DIRS to programs.herdr-core.package''s bin, because Herdr puts the folder it found hc in first on its PATH and every terminal inherits it: found in /run/current-system/sw/bin, that put the plain sudo ahead of /run/wrappers/bin''s setuid one in every pane.'
tags: [herdr, nixos, path]
status: stable
generated: { by: claude-code/opus-5-5, at: 2026-11-01T15:15:00-08:00 }
sources:
  - id: app-core-bin-rs
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.11/src/core_bin.rs
    title: 'herdr-app src/core_bin.rs (find, use_core, usual_dirs)'
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md (packaging notes: environment leaks, the core is pinned)'
---

**Where:** [herdr module](../modules/herdr.md) (`programs.herdr-app`), the
[herdr sub-flake](../packages/herdr.md)'s `pkgs/herdr-app-wrap.nix`; live on
[nebula](../hosts/nebula.md) through [nebula-herdr](../modules/nebula-herdr.md).

## Context

`sudo` failed in every Herdr pane: "sudo must be owned by uid 0 and have the
setuid bit set". Herdr looks for hc in settings.json's `core`, then its own
PATH, then a list of usual folders that includes
`/run/current-system/sw/bin`, then the login shell's PATH. Whatever it finds,
`use_core` puts that folder first on the app's PATH, so mods can run
hc.[^app-core-bin-rs] herdr-core passes the app's environment to every
terminal it starts.

The modules set no PATH, on purpose, since anything the wrapper exports
reaches every terminal.[^subflake-readme] So the app found hc in the system
profile and put that folder first, ahead of `/run/wrappers/bin`, where NixOS
keeps the setuid `sudo`. The profile's `sudo` is the plain store copy.

## Decision

- `herdr-app-wrap.nix` takes `pinCore`. The common module passes
  `programs.herdr-core.package` when the core is enabled, and the wrapper
  `--set`s `HERDR_CORE_DIRS` to its bin.
- That variable replaces every place Herdr looks except a `core` in
  settings.json.[^app-core-bin-rs] The folder that lands first on PATH is
  then the core's own bin, which holds only `hc` and `herdr-core` and
  shadows nothing.
- `HERDR_CORE_DIRS` reaches the terminals too. That's harmless, because only
  herdr-app reads it.
- Not `programs.herdr-app.settings.core`. That would pin hc as well, but the
  merge writes into nebula's stowed `settings.json`, which is a repo file, so
  a store path would land in git and change on every core bump
  ([stow decision](herdr-app-config-via-stow.md)).

## Consequences

- A pane's PATH now starts with herdr-core's bin, followed by the session's
  PATH, with `/run/wrappers/bin` ahead of the system profile. Checked in a
  live pane on 2026-11-01, after the switch.
- `HERDR_CORE_DIRS` is upstream's test hook (commented `Tests:`), not a
  documented setting, so an app bump can drop it. If `sudo` breaks in panes
  after a bump, check a pane's PATH first.
- A `core` key in settings.json still beats the pin, and its folder lands
  first on every pane's PATH.
- The standalone `nix run` package still searches, with its core suffixed to
  PATH. On a NixOS host whose system profile holds hc, its panes get the old
  order.

[^app-core-bin-rs]: herdr-app `src/core_bin.rs`: `find` (the lookup order and `HERDR_CORE_DIRS`), `use_core` (folder first on PATH) and `usual_dirs`
[^subflake-readme]: `flakes/herdr/README.md`: packaging notes, "Environment leaks into every terminal" and "The core is pinned"
