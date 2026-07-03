---
type: Neovim Plugin
title: nvim-tmux-navigation
description: One set of keys (<C-h/j/k/l>) to move across nvim splits and tmux panes, including from terminal mode; disabled when a pane is zoomed.
resource: home/nvim/.config/nvim/lua/plugins/tmux.lua
tags: [nvim-plugin, tmux, keymaps]
timestamp: '2026-07-02T00:00:00-07:00'
---

Makes `<C-h/j/k/l>` navigate seamlessly between Neovim splits and tmux panes
(`<C-\>` last-active, `<C-Space>` next), with `disable_when_zoomed = true`
so a zoomed tmux pane isn't accidentally left. The same four motions are
also mapped in **terminal mode**, plus `<M-Esc>` to leave terminal mode.
The tmux side of this handshake lives in the [tmux
module](../../modules/tmux.md)'s config.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/tmux.lua`](../../../home/nvim/.config/nvim/lua/plugins/tmux.lua)
- Upstream: <https://github.com/alexghergh/nvim-tmux-navigation>
