---
type: Neovim Plugin
title: mini.splitjoin
description: Split/join argument lists across lines with sj/sk; the default toggle mapping is disabled in favor of explicit directions.
resource: home/nvim/.config/nvim/lua/plugins/mini-splitjoin.lua
tags: [nvim-plugin, editing, keymaps]
timestamp: '2026-07-02T00:00:00-07:00'
---

Splits or joins bracketed constructs (argument lists, tables, arrays). The
plugin's default *toggle* mapping is disabled (`toggle = ""`) in favor of
explicit, direction-stating maps: `sj` join, `sk` split (normal and visual).

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/mini-splitjoin.lua`](../../../home/nvim/.config/nvim/lua/plugins/mini-splitjoin.lua)
- Upstream: <https://github.com/echasnovski/mini.splitjoin>
