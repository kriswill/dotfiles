---
type: Neovim Config
title: Keymap Topology
description: Space-leader keymap layout — which namespace lives where, core non-leader maps, and which plugin owns each group.
resource: home/nvim/.config/nvim/lua/config/keymaps.lua
tags: [nvim, keymaps]
timestamp: '2026-07-02T00:00:00-07:00'
---

Leader and localleader are both **space**. Core maps live in
[`lua/config/keymaps.lua`](../../home/nvim/.config/nvim/lua/config/keymaps.lua);
the bulk of the surface is defined next to the plugin that owns it —
this doc is the map of the map. [which-key](plugins/which-key.md) (helix
preset, 300 ms delay) names the groups and pops up the reference; press
`<leader>?` for buffer-local maps.

## Core maps (config/keymaps.lua)

- `jk` / `ii` (insert) — leave insert mode.
- `gx` — open URL/file under cursor via `vim.ui.open` (cross-platform opener).
- `<` / `>` (visual) — re-select after indent, so repeated indenting works.
- `<leader>cr` — copy buffer-relative path to clipboard.
- `<leader>cf` — format buffer via LSP, filtered to efm only — the same
  single-formatter filter as format-on-save (see [LSP](lsp.md)).

## Leader namespaces

| Prefix | Group (which-key) | Owner |
|---|---|---|
| `<leader><space>`, `<leader>,`, `<leader>e`, `<leader>.` | smart-find / buffers / explorer / scratch | [snacks](plugins/snacks.md) |
| `<leader>f` | [F]ile — find/recent/projects | [snacks](plugins/snacks.md) |
| `<leader>fe` | dir[e]nv — allow/deny/reload/edit | [direnv](plugins/direnv.md) |
| `<leader>g` | [g]it — pickers, lazygit, gitbrowse | [snacks](plugins/snacks.md) |
| `<leader>s` | [s]earch — grep, symbols, registers, undo, plugin inventory (`<leader>sp`) | [snacks](plugins/snacks.md) |
| `<leader>u` | [u]i toggles — spell, wrap, diagnostics, inlay hints, dim, … | [snacks](plugins/snacks.md) toggles + [treesitter-context](plugins/treesitter-context.md) (`<leader>ut`) |
| `<leader>d`, `<F5>`–`<F12>`, `<M-b>`/`<M-B>` | debug — DAP continue/step/breakpoints | [debug](plugins/debug.md) (loads nvim-dap on first press) |
| `<leader>a` / `<leader>A` | swap parameter next/prev | [treesitter-textobjects](plugins/treesitter-textobjects.md) |
| `<leader>c` | code — `cf` format, `cr` copy path, `cR` rename file | core + [LSP](lsp.md) + [snacks](plugins/snacks.md) |
| `<leader>z` / `<leader>Z` / `<leader>n` / `<leader>b` | zen / zoom / notifications / buffer | [snacks](plugins/snacks.md) |

## Non-leader surface

- `gd` `gD` `gI` `gy` — LSP goto via snacks pickers; `af`/`if`, `ac`/`ic`,
  `ao`, `as` — treesitter text objects; `sj`/`sk` — split/join args
  ([mini-splitjoin](plugins/mini-splitjoin.md)); `-` — parent dir as buffer
  ([oil](plugins/oil-nvim.md)).
- `<C-h/j/k/l>` — seamless nvim-split ↔ tmux-pane navigation, also mapped in
  terminal mode ([tmux](plugins/tmux.md)); `<C-/>` — snacks terminal;
  `]]`/`[[` — jump word references.

## Known quirks

- The which-key spec names groups (`<leader>t` test, `<leader>R` replace,
  `<leader>N` package-info, `<leader>x` diagnostics) that currently have no
  bound maps — leftovers from a previous config generation.

## Citations

- [`lua/config/keymaps.lua`](../../home/nvim/.config/nvim/lua/config/keymaps.lua)
- [`lua/plugins/snacks/keymaps/`](../../home/nvim/.config/nvim/lua/plugins/snacks/keymaps/)
