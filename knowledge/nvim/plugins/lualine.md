---
type: Neovim Plugin
title: lualine.nvim
description: Global statusline themed by kanagawa, built from lualine-so-fancy components (mode, diagnostics, branch/diff, LSP servers).
resource: home/nvim/.config/nvim/lua/plugins/lualine.lua
tags: [nvim-plugin, ui]
timestamp: '2026-07-02T00:00:00-07:00'
---

Single global statusline (`globalstatus = true`) using the
[kanagawa](colorscheme.md) lualine theme and the bundled
`lualine-so-fancy.nvim` component set: `fancy_mode`, filename with relative
path, `fancy_diagnostics` + `fancy_searchcount`, then `fancy_branch` (icon
tinted `#fc5603`), `fancy_diff`, `fancy_lsp_servers`, progress. Refreshes
every 100 ms; thin `│` component separators, no section separators; nerd-font
glyphs documented inline with codepoint comments (U+F0F6 modified, U+F023
readonly, …). Statusline disabled for utility filetypes (help, Trouble,
toggleterm, …).

The LSP-servers segment reflects whatever [LSP](../lsp.md) has attached.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/lualine.lua`](../../../home/nvim/.config/nvim/lua/plugins/lualine.lua)
- Upstream: [https://github.com/nvim-lualine/lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)
- Bundled dep: [https://github.com/meuter/lualine-so-fancy.nvim](https://github.com/meuter/lualine-so-fancy.nvim)
