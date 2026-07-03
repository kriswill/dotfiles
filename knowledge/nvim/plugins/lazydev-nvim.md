---
type: Neovim Plugin
title: lazydev.nvim
description: Neovim-API aware lua-language-server workspace for config development; ft-lazy on lua, luv types on vim.uv.
resource: home/nvim/.config/nvim/lua/plugins/lazydev-nvim.lua
tags: [nvim-plugin, lsp, lua]
timestamp: '2026-07-02T00:00:00-07:00'
---

Configures [luals](../lsp.md) for editing this very config: loads the luv
(libuv) type library when `vim.uv` appears in a buffer. The only `ft`-lazy
plugin (`trigger = { ft = "lua" }` in the [dispatcher](../architecture.md)) —
it never loads unless a Lua buffer opens. Its completions are injected into
[blink.cmp](blink-cmp.md) via `lazydev.integrations.blink` with a +100 score
offset.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/lazydev-nvim.lua`](../../../home/nvim/.config/nvim/lua/plugins/lazydev-nvim.lua)
- Upstream: [https://github.com/folke/lazydev.nvim](https://github.com/folke/lazydev.nvim)
