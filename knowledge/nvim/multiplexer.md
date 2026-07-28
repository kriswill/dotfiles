---
type: Neovim Config
title: Multiplexer Navigation
description: One set of keys (<C-h/j/k/l>) walking nvim splits and then the surrounding terminal multiplexer's panes — a local module with tmux and herdr backends, chosen from the environment at startup.
resource: home/nvim/.config/nvim/lua/config/multiplexer.lua
tags: [nvim, keymaps, tmux, herdr]
timestamp: '2026-07-28T12:30:00-07:00'
---

`<C-h/j/k/l>` move between nvim windows; once a motion runs off the edge of
the window layout it is handed to the multiplexer, which moves pane focus
instead. `<C-\>` is last-active and `<C-Space>` is cycle-next. A zoomed pane
is never left this way (`disable_when_zoomed`).

The backend is picked once at startup from the environment — `$TMUX` →
[tmux](../modules/tmux.md), else `$HERDR_PANE_ID` → [herdr](../modules/herdr.md),
else neither and the keys are plain `:wincmd` motions. tmux is checked first
because nvim inside tmux inside a herdr pane inherits `$HERDR_PANE_ID` too, and
the *innermost* multiplexer is the one that owns the splits around us;
`vim.g.multiplexer` overrides the guess. `:MultiplexerStatus` reports which one
is live.

Backends differ in reach: tmux gets `select-pane -L/-D/-U/-R/-l/-t:.+`, so all
six motions cross panes. herdr's CLI only does directional focus (0.7.4), so
under herdr `<C-\>` and `<C-Space>` stay inside nvim. `<C-Space>` is herdr's
prefix key anyway, so nvim never sees it there.

nvim is only half the handshake — the multiplexer has to forward the chord to
a vim-running pane rather than acting on it. See the [vim-aware pane
navigation decision](../decisions/vim-aware-pane-navigation.md) for how each
side does that, and why this replaced the `nvim-tmux-navigation` plugin.

Terminal-mode `<C-h/j/k/l>` (plus `<M-Esc>` to leave terminal mode) are mapped
here too, but only move between nvim windows: the job in a terminal buffer owns
its own control keys.

## Citations

- [`lua/config/multiplexer.lua`](../../home/nvim/.config/nvim/lua/config/multiplexer.lua)
- [`home/tmux/.config/tmux/tmux.conf`](../../home/tmux/.config/tmux/tmux.conf) — the `is_vim` half
- [`home/herdr/.config/herdr/config.toml`](../../home/herdr/.config/herdr/config.toml) — the [herdr-nav](../packages/herdr-nav.md) half
- [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) — origin of the `is_vim` pattern
- [`docs/tmux.md`](../../docs/tmux.md)
