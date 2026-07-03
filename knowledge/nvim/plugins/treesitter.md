---
type: Neovim Plugin
title: nvim-treesitter
description: Treesitter parsers on the main branch (0.12+ API) — async install, highlight+indent per filetype, TSUpdate wired to PackChanged.
resource: home/nvim/.config/nvim/lua/plugins/treesitter.lua
tags: [nvim-plugin, treesitter]
timestamp: '2026-07-02T00:00:00-07:00'
---

Tracks nvim-treesitter's `main` branch (the rewritten Neovim 0.12+ API, no
`ensure_installed` config table). The plugin explicitly does not support
lazy-loading, so `trigger = "now"`, ordered before
[treesitter-textobjects](treesitter-textobjects.md) in the
[load order](../architecture.md).

## Mechanics

- ~19 parsers installed asynchronously via `require("nvim-treesitter").install`
  (bash, c/cpp, go, html, js/tsx/ts, latex, lua, markdown + markdown_inline,
  nix, scss, svelte, typst, vim/vimdoc, vue) — a no-op when already present.
- A `FileType` autocmd starts highlighting (`vim.treesitter.start`) and sets
  treesitter `indentexpr` for a matching filetype list; parsers not yet
  installed simply no-op and light up once install finishes.
- A `PackChanged` autocmd runs `:TSUpdate` whenever vim.pack installs or
  updates the plugin itself, keeping parsers pinned to versions matching the
  plugin — the vim.pack analog of lazy.nvim's `build = ":TSUpdate"`.

Folding is treesitter-driven via `foldexpr` (see [options](../options.md));
[treesitter-context](treesitter-context.md) and the markdown highlight
overrides in [kanagawa](colorscheme.md) build on these parsers.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/treesitter.lua`](../../../home/nvim/.config/nvim/lua/plugins/treesitter.lua)
- Upstream: [https://github.com/nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
