---
type: Neovim Config
title: Editor Options
description: Core vim.opt settings — 2-space indent defaults, treesitter folds, hidden cmdline, system clipboard, transparency-friendly UI.
resource: home/nvim/.config/nvim/lua/config/options.lua
tags: [nvim, options]
timestamp: '2026-07-02T00:00:00-07:00'
---

Baseline editor behavior set in
[`lua/config/options.lua`](../../home/nvim/.config/nvim/lua/config/options.lua),
loaded before any plugin (see [architecture](architecture.md)). The
non-obvious choices:

## Highlights

- **Indent**: 2-space defaults (`tabstop`/`softtabstop`/`shiftwidth = 2`,
  `expandtab`, `smartindent`, `breakindent`). Per-project deviations are
  auto-detected by [vim-sleuth](plugins/vim-sleuth.md), which overrides these
  per buffer.
- **Folds from treesitter**: `foldmethod = "expr"` with
  `foldexpr = "nvim_treesitter#foldexpr()"` and `foldlevel = 20` so buffers
  open unfolded — depends on [treesitter](plugins/treesitter.md) parsers.
- **Quiet chrome**: `cmdheight = 0` (command line hidden until typing),
  `winborder = "rounded"` plus rounded diagnostic floats, `cursorline` on.
  Line numbers are relative + absolute (`relativenumber` + `number`).
- **Clipboard**: `unnamedplus` appended — yank/delete go straight to the
  system clipboard.
- **Search**: `ignorecase` + `smartcase` (capital letters opt into
  case-sensitivity).
- **Sessions**: fat `sessionoptions` (buffers, folds, terminal, winpos, …);
  swapfiles disabled.
- **Splits**: open right/below; `iskeyword` includes `-` so kebab-case words
  are single objects.
- **Scrolling**: `scrolloff = 5`; no line wrap by default (the
  [markdown ftplugin](filetypes.md) turns wrap on for prose).

## Transparency

`lua/config/transparency.lua` complements these by clearing `bg` on Normal,
float, popup, sign/fold-column and nvim-notify highlight groups so the
terminal's background (and blur) shows through; the
[kanagawa colorscheme](plugins/colorscheme.md) is loaded with
`transparent = true` to match.

## Citations

- [`lua/config/options.lua`](../../home/nvim/.config/nvim/lua/config/options.lua)
- [`lua/config/transparency.lua`](../../home/nvim/.config/nvim/lua/config/transparency.lua)
