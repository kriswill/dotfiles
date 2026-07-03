---
type: Neovim Plugin
title: oil.nvim
description: Directories as editable buffers, opened floating with `-`; hidden files shown, icons via mini.icons.
resource: home/nvim/.config/nvim/lua/plugins/oil-nvim.lua
tags: [nvim-plugin, files]
timestamp: '2026-07-02T00:00:00-07:00'
---

Edit the filesystem like a buffer: `-` opens the parent directory in a
floating window (`:Oil --float`), with hidden files visible and icons from
the bundled mini.icons. Complements the [snacks](snacks.md) explorer
(sidebar view) rather than replacing it, and the snacks plugin-inventory
picker opens plugin directories through oil.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/oil-nvim.lua`](../../../home/nvim/.config/nvim/lua/plugins/oil-nvim.lua)
- Upstream: <https://github.com/stevearc/oil.nvim>
- Bundled dep: <https://github.com/echasnovski/mini.icons>
