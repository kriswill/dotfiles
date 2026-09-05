---
type: Neovim Config
title: Multiplexer Navigation
description: 'One set of keys (<C-h/j/k/l>) walking nvim splits and then the surrounding terminal multiplexer''s panes — a local module with tmux and herdr backends, chosen from the environment at startup.'
resource: home/nvim/.config/nvim/lua/config/multiplexer.lua
tags: [nvim, keymaps, tmux, herdr]
generated: { by: okflight/0.4.0, at: 2026-07-28T12:30:00-07:00 }
sources:
  - id: lua-config-multiplexer-lua
    resource: ../../home/nvim/.config/nvim/lua/config/multiplexer.lua
    title: '`lua/config/multiplexer.lua`'
  - id: home-tmux-config-tmux-tmux-conf
    resource: ../../home/tmux/.config/tmux/tmux.conf
    title: '`home/tmux/.config/tmux/tmux.conf`'
  - id: home-herdr-config-herdr-config-toml
    resource: ../../home/herdr/.config/herdr/config.toml
    title: '`home/herdr/.config/herdr/config.toml`'
  - id: vim-tmux-navigator
    resource: https://github.com/christoomey/vim-tmux-navigator
    title: vim-tmux-navigator
  - id: docs-tmux-md
    resource: ../../docs/tmux.md
    title: '`docs/tmux.md`'
---

`<C-h/j/k/l>` move between nvim windows; once a motion runs off the edge of
the window layout it is handed to the multiplexer, which moves pane focus
instead. `<C-\>` is last-active and `<C-Space>` is cycle-next.

`disable_when_zoomed` gates **the four directional keys only**: running out of
windows is an implicit reason to leave, so escaping a zoomed pane that way would
be a surprise. `<C-\>` and `<C-Space>` are explicit "go elsewhere" commands and
deliberately *do* leave a zoomed pane — gating them would make both dead keys in
a zoomed single-window nvim.

The edge test is `winnr(dir)`, a query that moves nothing. That matters twice:
`:wincmd` failing (E11 in the command-line window) can't be mistaken for "at the
edge" and hand the pane away, and floating windows aren't counted — `winnr("$")`
counts them and `:wincmd w` walks *into* them, so window cycling walks the split
layout explicitly instead.

The backend is picked once at startup from the environment — `$TMUX` →
[tmux](../modules/tmux.md), else `$HERDR_PANE_ID` → [herdr](../modules/herdr.md),
else neither and the keys are plain window motions. tmux is checked first
because nvim inside tmux inside a herdr pane inherits `$HERDR_PANE_ID` too, and
the *innermost* multiplexer is the one that owns the splits around us.
`vim.g.multiplexer` overrides the guess; an unrecognised value warns once and
falls back to detection, so `:MultiplexerStatus` can never name a backend that
isn't wired.

Backends differ in reach: tmux gets `select-pane -L/-D/-U/-R/-l/-t:.+`, so all
six motions cross panes. herdr's CLI only does directional focus (0.7.4), so
under herdr `<C-\>` and `<C-Space>` stay inside nvim. **`<C-Space>` in practice
only reaches nvim in a bare terminal**: both multiplexers are configured with
`ctrl+space` as their prefix (`tmux.conf`, herdr's `config.toml`). Under tmux
that shadowing also makes tmux's own `bind-key -n 'C-Space' … send-keys
C-Space` unreachable — `set -g prefix C-space` claims the chord as the prefix
before any root-table binding is consulted, so the forwarding half never runs
either. The `n` motion is kept correct anyway, for a bare terminal or a rebound
prefix.

Hand-offs are synchronous and their exit status is believed — "did the
multiplexer actually move?" is the only input to the last-active bookkeeping,
and `tmux select-pane -l` genuinely fails (exit 1, "no last pane") in a
single-pane window, which is exactly when `<C-\>` must fall back to `:wincmd p`.
That bookkeeping is also refreshed by a `FocusGained` autocmd, so pane switches
made *outside* these keys (tmux's `prefix + o`, a mouse click, herdr's sidebar)
are not invisible; `tmux.conf` sets `focus-events on` for this. Its one blind
spot: `FocusGained` also fires when the terminal application itself regains
focus, which is indistinguishable from a pane switch.

The herdr backend resolves its pane through the server (`--current`) rather than
`$HERDR_PANE_ID`, which is read for detection only: herdr pane ids are
workspace-scoped, so moving the pane re-ids it while nvim keeps the id it
inherited at startup. (`pane focus`, `pane layout` and `pane process-info`
resolve `--current` server-side; `pane current` does not.)

nvim is only half the handshake — the multiplexer has to forward the chord to
a vim-running pane rather than acting on it. See the [vim-aware pane
navigation decision](../decisions/vim-aware-pane-navigation.md) for how each
side does that, and why this replaced the `nvim-tmux-navigation` plugin.

Because the multiplexer forwards the chord whatever mode nvim is in, the keys
are mapped in three modes:

- **normal** — all six motions.
- **insert** — the four directional keys, and **only when a backend was
  detected**. They leave insert mode and then navigate normally. Without this the
  forwarded chord is taken as text input (`<C-h>` deletes a character, `<C-j>`
  inserts a line break, `<C-k>` starts a digraph); with no multiplexer nothing
  forwards the chord, so vim's own insert-mode meanings are left alone.
- **terminal** — the four directional keys plus `<M-Esc>` to leave terminal
  mode. Moving to another nvim window leaves terminal mode; handing off to the
  multiplexer does **not** (the pane just loses focus and comes back still in
  terminal mode). With nothing in that direction and no hand-off available the
  key does nothing at all, rather than dropping the user into normal mode as a
  side effect of a keypress that moved nothing.
