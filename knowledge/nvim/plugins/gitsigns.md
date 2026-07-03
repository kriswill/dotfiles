---
type: Neovim Plugin
title: gitsigns.nvim
description: Git hunk signs in the sign column — stock setup, no options.
resource: home/nvim/.config/nvim/lua/plugins/gitsigns.lua
tags: [nvim-plugin, git]
timestamp: '2026-07-02T00:00:00-07:00'
---

Default `setup()` — add/change/delete signs only. Hunk-level git
interaction happens through [snacks](snacks.md) pickers and lazygit instead,
so gitsigns stays a passive indicator.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/gitsigns.lua`](../../../home/nvim/.config/nvim/lua/plugins/gitsigns.lua)
- Upstream: <https://github.com/lewis6991/gitsigns.nvim>
