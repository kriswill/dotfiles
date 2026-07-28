---
type: Decision
title: Keep One Set of Pane-Navigation Keys Across tmux and herdr
description: Drop the nvim-tmux-navigation plugin for a local module with tmux and herdr backends, and give herdr the conditional binding it lacks via a herdr-nav shim rather than surrendering ctrl+h/j/k/l.
tags: [nvim, tmux, herdr, keymaps]
timestamp: '2026-07-28T12:30:00-07:00'
---

**Status:** active. **Where:** [multiplexer navigation](../nvim/multiplexer.md),
[herdr-nav](../packages/herdr-nav.md), [herdr](../modules/herdr.md),
[tmux](../modules/tmux.md).

## Context

`<C-h/j/k/l>` had walked nvim splits and tmux panes as one continuous surface
for years, via `alexghergh/nvim-tmux-navigation` in nvim plus the classic
`is_vim` + `if-shell` binds in `tmux.conf`. Adopting herdr as a second
multiplexer (`941d4d8` bound `ctrl+h/j/k/l` to `focus_pane_*`) broke that: the
plugin only speaks tmux, and herdr's binding is unconditional, so nvim in a
herdr pane never received the chord at all — inside nvim the keys moved the
wrong thing.

Two gaps, then: nvim couldn't drive herdr, and herdr had no equivalent of
tmux's `if-shell` escape hatch. herdr 0.7.4 has no vim-awareness of any kind
(no passthrough config, nothing in the binary's config surface).

## Decision

Replace the plugin with `lua/config/multiplexer.lua` — the same edge-detection
logic (move a window, and hand off only if `winnr()` didn't change) behind a
backend table, picked from `$TMUX` / `$HERDR_PANE_ID` at startup. tmux gets
`select-pane`; herdr gets `herdr pane focus`. Dropping the dependency was
cheaper than wrapping it: the plugin is ~120 lines of tmux-specific shelling
out, and the reusable part is the edge check.

For the herdr side, rebuild `is_vim` out of herdr's own CLI:
`ctrl+h/j/k/l` become `[[keys.command]]` shells calling
[herdr-nav](../packages/herdr-nav.md), which inspects `herdr pane
process-info` and either `send-keys` the chord to a vim-running pane or moves
focus. Verified end to end: an injected `ctrl+h` fires nvim's `<C-h>` mapping.

Alternatives rejected: leaving herdr's unconditional `focus_pane_*` bound and
giving nvim different keys inside herdr (defeats the muscle memory the whole
integration exists for); or unbinding `ctrl+h/j/k/l` in herdr entirely so nvim
always wins (then shell panes lose direct pane switching). The shim keeps one
key set meaning one thing everywhere; `prefix+h/j/k/l` stays as a fallback that
skips it.

## Consequences

- One nvim module now covers both multiplexers, and adding a third is a backend
  table entry.
- herdr pays a subprocess per `ctrl+h/j/k/l` press (a shell plus one or two CLI
  round-trips over the socket). tmux's `if-shell` + `ps` is the same shape of
  cost.
- herdr's CLI has no last/next-pane command, so `<C-\>` and `<C-Space>` stay
  inside nvim there while they cross panes under tmux. Revisit if herdr adds
  them.
- `herdr-nav` must be on the herdr **server's** PATH; it ships with herdr on
  both OSes, but a config reload before a system rebuild leaves the keys
  no-ops.
- If herdr ever grows native vim-awareness, the shim collapses back into four
  `focus_pane_*` lines.

## Citations

- Commits `941d4d8` (herdr ctrl+hjkl binds), `6414751`
- [`pkgs/herdr-nav.sh`](../../pkgs/herdr-nav.sh)
- [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator)
- [alexghergh/nvim-tmux-navigation](https://github.com/alexghergh/nvim-tmux-navigation) — the replaced plugin
