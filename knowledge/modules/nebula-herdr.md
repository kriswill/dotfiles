---
type: NixOS Module
title: Herdr on nebula
description: 'nebula''s herdr settings: enables the Herdr desktop app and hc for k with linger declared and telemetry off, plus the daily herdr-update-check timer (the fork, core and app), leaving every config file to the home/herdr-core and home/herdr-app stow packages.'
resource: modules/hosts/nebula/herdr.nix
tags: [nixos-module, host-specific, herdr]
generated: { by: hermes-agent/gpt-6.1-sol, at: 2026-11-04T14:21:34-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md (config files and stow, updating)'
  - id: app-settings-0113
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.13/src/settings.rs
    title: 'Herdr 0.1.13 settings.rs (default terminal font and font_ligatures)'
---

On top of the TUI that [herdr](herdr.md) installs everywhere, nebula turns on
`programs.herdr-app.enable`, `programs.herdr-core.users = [ "k" ]` (linger is
declared by the module's default) and `services.herdr-update-check.enable`.

Choices:

- **Config through stow, not Nix.** No file option is set.
  - `home/herdr-core` holds a commented `config.toml` with every key at its
    default.
  - `home/herdr-app` holds a `settings.json` seeded with
    `{"telemetry": false}`, so the link exists before the first launch and
    every Settings-screen save or zoom change lands in the repo.
  - `keys.json`, layouts and themes are captured when first customized, with
    `dots-adopt herdr-app .config/herdr-app/<file>`. The stow package now
    also holds `keys.json`, `themes/kanagawa.json`, the `personal` layout and
    the `vim-nav` and `pane-rotate` mods: the herdr TUI's keys and theme,
    ported ([decision](../decisions/herdr-app-keys-via-hosted-mods.md)).
    Since 2026-11-03 the layout's tab bar ends in the `herdr-updates` mod:
    an update icon whose hover card lists `herdr-update-check --json`'s
    releases and stale processes, each linking to a `herdr-changelog` pane
    ([decision](../decisions/herdr-updates-mod.md)).
  - Herdr's live reload doesn't see edits to the repo copy. Write through
    the `~/.config/herdr-app/` link, then check `herdr-app status`.
- **Terminal font: Herdr's default** (JetBrains Mono) at `font_size` 17,
  `zoom` 1.2, dark `appearance`, and `font_ligatures: false`
  (`settings.json`).[^app-settings-0113] `settings.json` sets no
  `font` since 2026-11-04. From 2026-11-01 it set MesloLGS Nerd Font for its
  braille glyphs. JetBrains Mono 2.304 has none (U+2800–28FF), and Herdr
  0.1.11's sprites covered only box drawing, blocks and powerline, so braille
  fell back to a proportional system font. Herdr 0.1.12 and later draw
  braille as sprites, like Ghostty, so the override was dropped. The Meslo
  package itself comes from snowglobe-factory's desktop module, not from
  this repo.
  - Both packages are darwin-skipped until the macs enable them
    ([decision](../decisions/herdr-app-config-via-stow.md)).
- **Linger on.** It was confirmed while choosing the design: hc wants it and
  would set it anyway. k's user manager now starts at boot, so
  `default.target`'s timers can fire before login. herdr-update-check waits
  for a notification daemon for that reason.
- **Panes don't see the session.** Pane shells inherit the environment of
  hc's core (`hc-hold-*.service`), which was frozen when it spawned. With
  linger, that can be before Hyprland, so the panes have no
  `WAYLAND_DISPLAY`. zsh's `session-env.zsh` re-syncs the variables before
  each command
  ([decision](../decisions/herdr-pane-session-env.md)). A program that
  started earlier, such as a running Claude Code, keeps the old values until
  it is restarted.
- **One update check.** It replaces nebula's old fork-only unit
  ([herdr-update-check](herdr-update-check.md), now deprecated) under the same
  unit name. It reports upstream releases past the fork and `sources.json`,
  and stale running builds.
  - For the fork: rebase and retag it, then repoint `herdr-cli.url`.
  - For the core and app: `bun flakes/herdr/update.ts`, then `nrs`.
  - After an `nrs` that bumped anything, run `herdr-update-check` by hand to
    catch a herdr server, core or window that needs
    restarting.[^subflake-readme]

Host-specific file for [nebula](../hosts/nebula.md), merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/herdr.nix`](../../modules/hosts/nebula/herdr.nix)

[^subflake-readme]: `flakes/herdr/README.md`: config files and stow; updating and upgrade notices
[^app-settings-0113]: Herdr 0.1.13 `src/settings.rs`: `DEFAULT_FONT`, `Person.font_ligatures`, and `Settings::compose`
