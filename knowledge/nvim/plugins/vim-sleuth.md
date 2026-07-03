---
type: Neovim Plugin
title: vim-sleuth
description: Auto-detects per-buffer indentation from file content and neighbors — overrides the 2-space defaults where projects differ.
resource: home/nvim/.config/nvim/lua/plugins/vim-sleuth.lua
tags: [nvim-plugin, editing]
timestamp: '2026-07-02T00:00:00-07:00'
---

Bare spec, no configuration. Sets `shiftwidth`/`expandtab` per buffer by
inspecting the file and its neighbors, so the global 2-space defaults from
[options](../options.md) yield gracefully inside projects with different
conventions.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/vim-sleuth.lua`](../../../home/nvim/.config/nvim/lua/plugins/vim-sleuth.lua)
- Upstream: <https://github.com/tpope/vim-sleuth>
