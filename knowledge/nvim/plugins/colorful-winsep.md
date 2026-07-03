---
type: Neovim Plugin
title: colorful-winsep.nvim
description: Colors the separator around the active split in kanagawa oniViolet; also publishes the palette as _G.kanagawa_colors.
resource: home/nvim/.config/nvim/lua/plugins/colorful-winsep.lua
tags: [nvim-plugin, ui]
timestamp: '2026-07-02T00:00:00-07:00'
---

Draws the active window's separators in the [kanagawa](colorscheme.md)
palette's `oniViolet` on a transparent background, making the focused split
obvious in a sea of transparent panes. As a side effect its setup stashes the
computed palette in `_G.kanagawa_colors` for any later consumer.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/colorful-winsep.lua`](../../../home/nvim/.config/nvim/lua/plugins/colorful-winsep.lua)
- Upstream: [https://github.com/nvim-zh/colorful-winsep.nvim](https://github.com/nvim-zh/colorful-winsep.nvim)
