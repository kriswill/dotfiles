---
type: Decision
title: Let Stow Own Herdr's Config Files; Module File Options Default to Null
description: 'herdr-core''s config.toml and Herdr''s files live in the home/herdr-core and home/herdr-app stow packages (settings.json per-OS in home/herdr-app-darwin and home/herdr-app-linux, since zoom differs by display), and the sub-flake''s file options (settings, keys) default to null so the flake never touches them: Herdr''s saves write through symlinks, so stow links capture in-app edits for versioning, which a Nix store link cannot.'
tags: [herdr, stow, config]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-01T12:00:00-08:00 }
sources:
  - id: app-persist-rs
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.11/src/persist.rs
    title: 'herdr-app src/persist.rs (write_atomic resolves symlinks; tests)'
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md (config files and stow)'
---

**Where:** [herdr module](../modules/herdr.md),
[nebula-herdr](../modules/nebula-herdr.md).

## Context

Herdr writes `settings.json` itself, from the Settings screen and zoom, and
writes `keys.json`'s defaults when it's missing. Apps that save by atomic
rename break stow links. Noctalia and Helium do, which is why their configs
are snapshotted under `config/` instead of being stowed
([stow tree pattern](../patterns/stow-tree.md)). A read-only Nix store link
would break the Settings screen outright. The user wanted any file the app
edits versioned through stow, with the stow wiring kept out of the flake.

## Decision

- **Stow works here.** Herdr's `write_atomic` resolves the symlink chain
  before writing its temp file and renaming it onto the target, and upstream
  tests that links survive.[^app-persist-rs] A stowed `settings.json`
  therefore collects the app's edits in the repo. The core never writes
  `config.toml`.
- **The flake knows nothing about stow.** Its file options, `herdr-core.settings`
  and `herdr-app.keys`, default to `null`, and `null` means hands off. Given
  content, each becomes a read-only `L+` store link. `herdr-app.settings`
  merges declared keys into the file at launch, writing through a link, and
  never touches the file when it's `{}`.
- **Every host uses stow** and sets none of them. `home/herdr-core` holds a
  commented `config.toml`. `home/herdr-app` holds everything shared (keys,
  layouts, mods, themes).
- **settings.json is per-OS**: `home/herdr-app-darwin` and
  `home/herdr-app-linux`, each skip-listed on the other OS in
  `modules/{darwin,nixos}/dotfiles-stow.nix`. One shared file had the zoom
  keys on each machine overwriting the other's value in git (1.3, 1.1, 0.9,
  1.1, 1.2, 1.0 over six commits). k's 5K display wants 1.0 and nebula's
  3440x1440 OLED wants 1.2. The darwin module's `core` pin
  (`/etc/herdr-core/hc`) also leaked through the shared file to nebula, where
  that path doesn't exist. Herdr has no include or layering for
  settings.json, and `HERDR_APP_HOME` relocates the whole app home, so
  neither could split one key. Per-OS rather than per-host: the macs share
  one setup, and a per-host split would need a new stow mechanism (the skip
  lists are per class) and more copies to keep in sync. Declaring the shared
  keys through `programs.herdr-app.settings` with an unstowed file was
  rejected because Settings-screen edits would stop reaching git.

## Consequences

- In-app edits show up as repo diffs, including zoom changes, in the
  running OS's settings.json. A shared setting (font, theme) changed in the
  app has to be copied into the other OS's file by hand.
- Moving a stowed settings.json while Herdr runs leaves the link dangling,
  and Herdr at once writes a new file through it, holding only the keys it
  always saves (`zoom`, `sounds`, `font_ligatures`, `minimum_contrast`). Its
  in-memory settings also fall back to defaults (theme, font size). That
  stray file in the old package makes the next restow conflict-skip the new
  one. Quit Herdr before a pull that moves the file, or repoint the link
  (`ln` + `mv -f`) before deleting the stray file. Seen on k on 2026-11-04;
  the app reloaded the full file once the link was repointed.
- Files the app creates later (`keys.json` on first launch, a duplicated
  layout or theme) start as real files. They need
  `dots-adopt herdr-app .config/herdr-app/<file>` before stow can own them;
  otherwise a later stow of the same path hits a real file and skips the
  package.
- The macs run Herdr too ([herdr-app-darwin-bundle](herdr-app-darwin-bundle.md)),
  so `home/herdr-core` and `home/herdr-app` deploy on both OSes.
- Landed in commit `4de98e9`.[^subflake-readme] The settings.json split
  came on 2026-11-04.

[^app-persist-rs]: herdr-app `src/persist.rs`: `resolve_target` and the `atomic_write_preserves_symlink_chains_and_dangling_targets` test
[^subflake-readme]: `flakes/herdr/README.md`: config files and stow
