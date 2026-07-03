---
type: Neovim Plugin
title: nvim-treesitter-context
description: Sticky scope header (up to 3 lines, cursor mode) pinned to the top of the window; toggled with <leader>ut.
resource: home/nvim/.config/nvim/lua/plugins/treesitter-context.lua
tags: [nvim-plugin, treesitter, ui]
timestamp: '2026-07-02T00:00:00-07:00'
---

Keeps the enclosing function/class signature visible at the top of the
window (`mode = "cursor"`, `max_lines = 3`). Deferred to `UIEnter`
(`trigger = "later"` in the [dispatcher](../architecture.md)) since it's
pure UI. Toggle with `<leader>ut`, alongside the snacks UI toggles in the
[keymap topology](../keymaps.md). Builds on [treesitter](treesitter.md).

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/treesitter-context.lua`](../../../home/nvim/.config/nvim/lua/plugins/treesitter-context.lua)
- Upstream: <https://github.com/nvim-treesitter/nvim-treesitter-context>
