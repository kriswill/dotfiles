---
type: Neovim Plugin
title: baleia.nvim
description: Renders ANSI escape codes as real colors — automatic for *.log buffers, on demand via :BaleiaColorize.
resource: home/nvim/.config/nvim/lua/plugins/baleia.lua
tags: [nvim-plugin, ui]
timestamp: '2026-07-02T00:00:00-07:00'
---

Turns raw ANSI escape sequences into highlighted text. A `BufWinEnter`
autocmd colorizes `*.log` files automatically; any other buffer can be
colorized with the `:BaleiaColorize` user command.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/baleia.lua`](../../../home/nvim/.config/nvim/lua/plugins/baleia.lua)
- Upstream: [https://github.com/m00qek/baleia.nvim](https://github.com/m00qek/baleia.nvim)
