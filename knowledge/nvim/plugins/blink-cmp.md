---
type: Neovim Plugin
title: blink.cmp
description: Completion engine (super-tab preset) over LSP/path/snippets/buffer with lazydev ranked first; cmdline completion with ghost text.
resource: home/nvim/.config/nvim/lua/plugins/blink-cmp.lua
tags: [nvim-plugin, completion]
timestamp: '2026-07-02T00:00:00-07:00'
---

The completion engine, pinned to `vim.version.range("1.*")` — the only
version-pinned plugin in the config. Uses the `super-tab` keymap preset,
auto-showing documentation, and sources `lazydev → lsp → path → snippets →
buffer`, with the [lazydev](lazydev-nvim.md) provider given
`score_offset = 100` so Neovim-API completions outrank everything while
editing config. Snippets come from the bundled friendly-snippets.

Cmdline completion is enabled too (cmdline + buffer sources, menu
auto-show, preselect + auto-insert, ghost text) — pairs with `cmdheight = 0`
from [options](../options.md), where the cmdline only appears when typing.

Completions are served by the servers in [LSP](../lsp.md).

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/blink-cmp.lua`](../../../home/nvim/.config/nvim/lua/plugins/blink-cmp.lua)
- Upstream: <https://github.com/saghen/blink.cmp>
- Bundled dep: <https://github.com/rafamadriz/friendly-snippets>
- Version pin: `vim.version.range("1.*")`
