---
type: Decision
title: Port the herdr TUI's Shell-Command Keys to Herdr as Mods Hosted in a Personal Layout
description: 'Herdr''s keys.json can''t run shell commands, so vim-aware ctrl+h/j/k/l and prefix+r rotate became the vim-nav and pane-rotate mods. Key commands only reach a mod copy that''s on screen, so a clone of the shipped main layout, `personal`, hosts both as empty floats.'
tags: [herdr, keymaps, nvim, stow]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-01T12:45:00-08:00 }
sources:
  - id: app-keys-rs
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.11/src/keys.rs
    title: 'herdr-app src/keys.rs (actions keys.json accepts; KeyBinding::load)'
  - id: app-mods-rs
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.11/src/mods.rs
    title: 'herdr-app src/mods.rs (send_command: only shown copies get key commands)'
  - id: app-floats-rs
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.11/src/window/floats.rs
    title: 'herdr-app src/window/floats.rs (an empty float draws no frame)'
  - id: tui-config
    resource: ../../home/herdr/.config/herdr/config.toml
    title: 'home/herdr/.config/herdr/config.toml (the TUI config the keys came from)'
---

**Where:** [Herdr on nebula](../modules/nebula-herdr.md),
[multiplexer navigation](../nvim/multiplexer.md),
[vim-aware pane navigation](vim-aware-pane-navigation.md).

## Context

The herdr TUI's config held settings and keys to carry over to Herdr, the
desktop app.[^tui-config] Most mapped directly. Two keys ran shell commands
through `[[keys.command]]`: ctrl+h/j/k/l called
[herdr-nav](../packages/herdr-nav.md), and prefix+r ran `pane-rotate.ts`.
Herdr's `keys.json` takes four kinds of action: an app command, `send:<text>`,
`terminal`, or `<mod>.<command>`. None of them runs a program.[^app-keys-rs]

A mod can run programs (`exec`, `hc`) and receives `<mod>.<command>` through
`nextCommand()`. But `send_command` delivers only to copies that are on
screen.[^app-mods-rs] Herdr's shipped layouts are read-only and replaced on
every start, so a mod can't be added to `main` without cloning it.

## Decision

- **Direct mappings:**
  - `shift+arrows` move between tabs (left/right) and spaces (up/down).
  - The ctrl+space chords are GPUI multi-keystroke bindings
    (`"ctrl-space v"`), which `KeyBinding::load` parses:[^app-keys-rs]
    `%`/`v` split right, `"`/`-` split down, `space` toggles the sidebar,
    and `h/j/k/l` are the plain `pane.go` fallback the TUI had. `%` and `"`
    are also bound under their `shift-5` / `shift-'` spellings.
  - The `kanagawa` theme is `themes/kanagawa.json`: ghostty's kanagawabones
    palette on nebula's `#0e0e0e` background, with the TUI kanagawa theme's
    `#7e9cd8` accent.
- **vim-nav:** ctrl+h/j/k/l send `vim-nav.<dir>`. If the focused terminal's
  program (from the app's program table) is vim, nvim or fzf, the mod presses
  the chord into it with `hc keys`. Otherwise it runs `pane.go`. It handles
  one command at a time, which replaces herdr-nav's lock. nvim's
  `multiplexer.lua` gained a `herdr-app` backend that runs
  `herdr-app do pane.go` at its edge.
- **pane-rotate:** prefix+r ports `pane-rotate.ts`. It splits the focused
  pane the other way, swaps the throwaway pane into the neighbour's slot, and
  closes it. Each step goes through `herdr-app do`, because each one needs
  the previous step's result (the new pane's id).
- **Hosting:** `layout.clone main → personal` adds both mods as floats on the
  root. They render an empty `div()`, and Herdr draws no frame around an
  empty float,[^app-floats-rs] so they're invisible but count as shown. The
  four ctrl+h/j/k/l keys and rotate are bound under `layout:personal`, so in
  any other layout ctrl+h/j/k/l still reach the program.

Rejected: leaving ctrl+h/j/k/l to the program and having only nvim hand off
at its edge. That needs no clone, but shell panes lose ctrl+h/j/k/l
navigation, and the
[original decision](vim-aware-pane-navigation.md) rejected that trade for
the TUI too.

## Consequences

- `personal` is a clone: it records `cloned_from: {main, 0.1.11}` and no
  longer receives upstream changes to `main`. After a Herdr update, diff it
  against the new `layouts/main.json` and fold in what's wanted, keeping the
  root's `floating` entries.
- The TUI's `onboarding`, `kitty_graphics`, `follow_nested_shells`,
  `agent_panel_sort`, `status_indicators`, `show_agent_labels_on_pane_borders`,
  `[ui.toast]` and the dotbar-usage `tab_bar_right` command have no Herdr
  setting. Kitty graphics and toasts are built in. The rest would need cloned
  mods (agents list, tab bar, pane header).
- Edits made to the repo copy of a stowed file don't trigger Herdr's live
  reload. Writes through the `~/.config/herdr-app/…` link do, so write
  through the link, or re-save there, and check `herdr-app status` for
  errors.
- Verified end to end on 2026-11-01 in a scratch tab:
  - ctrl+h from a split nvim moved between nvim's windows, then handed off
    to the shell pane.
  - ctrl+h/j/k/l from the shell moved between panes.
  - rotate flipped the panes both ways with both programs still running.

[^app-keys-rs]: herdr-app `src/keys.rs`: `valid_action`, `parse`
[^app-mods-rs]: herdr-app `src/mods.rs`: `send_command`, `set_shown_copies`
[^app-floats-rs]: herdr-app `src/window/floats.rs`: the `empty` check on the float body
[^tui-config]: the herdr TUI's `config.toml`
