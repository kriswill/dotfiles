---
type: Neovim Plugin
title: kanagawa.nvim
description: The kanagawa "wave" colorscheme, loaded first and transparent, with markdown highlight-link overrides.
resource: home/nvim/.config/nvim/lua/plugins/colorscheme.lua
tags: [nvim-plugin, ui]
timestamp: '2026-07-02T00:00:00-07:00'
---

Kanagawa is the repo-wide theme (the Nix side has a `lib.kanagawa` palette
helper); in Neovim it loads **first** in the
[plugin order](../architecture.md) so its palette is available to later
setups — [lualine](lualine.md) pulls its theme, and
[colorful-winsep](colorful-winsep.md) reads `kanagawa.colors` directly.

## Configuration

- `transparent = true`, gutter and float backgrounds forced to `none` —
  works with `config/transparency.lua` (see [options](../options.md)) so the
  terminal background shows through.
- `CursorLine` overridden to the `sumiInk2` palette color.
- Markdown-specific `@markup.*` treesitter captures re-linked (URLs →
  `Special`, labels → `WarningMsg`, italics → `Exception`, inline raw →
  `String`, list markers → `Function`, quotes → `Error`) to make rendered
  markdown structure pop — depends on [treesitter](treesitter.md)'s
  markdown_inline parser.
- Loads the `wave` variant explicitly via `kanagawa.load("wave")`.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/colorscheme.lua`](../../../home/nvim/.config/nvim/lua/plugins/colorscheme.lua)
- Upstream: <https://github.com/rebelot/kanagawa.nvim>
