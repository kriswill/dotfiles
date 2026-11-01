---
type: Decision
title: Let Stow Own Herdr's Config Files; Module File Options Default to Null
description: 'herdr-core''s config.toml and Herdr''s settings.json live in the home/herdr-core and home/herdr-app stow packages, and the sub-flake''s file options (settings, keys) default to null so the flake never touches them: Herdr''s saves write through symlinks, so stow links capture in-app edits for versioning, which a Nix store link cannot.'
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
- **nebula uses stow** and sets none of them. `home/herdr-core` holds a
  commented `config.toml`. `home/herdr-app` holds `settings.json`, seeded with
  `{"telemetry": false}` in the app's own `to_string_pretty` format, so the
  link exists before the first launch and diffs stay clean.

## Consequences

- In-app edits show up as repo diffs, including zoom changes.
- Files the app creates later (`keys.json` on first launch, a duplicated
  layout or theme) start as real files. They need
  `dots-adopt herdr-app .config/herdr-app/<file>` before stow can own them;
  otherwise a later stow of the same path hits a real file and skips the
  package.
- Both packages are darwin-skipped until the macs enable `programs.herdr-core` (`programs.herdr-app` is Linux-only for now).
- Not yet committed (2026-11-01).[^subflake-readme]

[^app-persist-rs]: herdr-app `src/persist.rs`: `resolve_target` and the `atomic_write_preserves_symlink_chains_and_dangling_targets` test
[^subflake-readme]: `flakes/herdr/README.md`: config files and stow
