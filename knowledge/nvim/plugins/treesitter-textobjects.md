---
type: Neovim Plugin
title: nvim-treesitter-textobjects
description: Treesitter text objects (af/if, ac/ic, ao, as) and parameter swapping, main branch, keymaps set explicitly.
resource: home/nvim/.config/nvim/lua/plugins/treesitter-textobjects.lua
tags: [nvim-plugin, treesitter, keymaps]
timestamp: '2026-07-02T00:00:00-07:00'
---

Structural text objects on top of [treesitter](treesitter.md) parsers
(`main` branch — keymaps are wired explicitly via `select_textobject` /
`swap_*` calls rather than the old keymaps table). Lookahead is enabled,
surrounding whitespace included, and selection modes are per-capture:
parameters charwise, functions linewise, classes blockwise.

## Keymaps

- `af`/`if` (visual/operator) — around/inner function
- `ac`/`ic` — around/inner class
- `ao` — around comment; `as` — language scope (locals group)
- `<leader>a` / `<leader>A` — swap parameter with next/previous

See the [keymap topology](../keymaps.md) for how these fit the wider layout.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/treesitter-textobjects.lua`](../../../home/nvim/.config/nvim/lua/plugins/treesitter-textobjects.lua)
- Upstream: [https://github.com/nvim-treesitter/nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
