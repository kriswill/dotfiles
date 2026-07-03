---
type: Neovim Plugin
title: snacks.nvim
description: The utility platform — picker, explorer, dashboard, terminal, zen, notifier — owning most of the leader keymap surface, plus a custom vim.pack plugin-inventory picker.
resource: home/nvim/.config/nvim/lua/plugins/snacks/
tags: [nvim-plugin, picker, ui, keymaps]
timestamp: '2026-07-02T00:00:00-07:00'
---

folke's snacks.nvim is the config's utility platform and the single biggest
keymap owner (see the [keymap topology](../keymaps.md)). The spec is a module
tree under `lua/plugins/snacks/` — `init.lua` wires `dashboard/`, `picker/`,
`keymaps/` (files, git, lsp, misc, search), and `config/` (toggles, globals).

## Enabled features

bigfile, explorer (right-sidebar layout), image, input, notifier (3 s
timeout), picker, quickfile, scroll, words, dashboard. Explicitly disabled:
indent, scope, statuscolumn. The dashboard shows braille-art banners
(hydra by default) and a footer computed from `vim.version()` +
`vim.pack.get()` plugin count; it is disabled under Neovide.

## Keymap surface

- **Files** — `<leader><space>` smart find, `<leader>,`/`<leader>fb`
  buffers, `<leader>e` explorer, `<leader>ff/fg/fr/fp/fc` files/git
  files/recent/projects/config.
- **Search** (`<leader>s*`) — grep (`<leader>/`, `sg`, `sw`), buffer lines,
  registers, autocmds, commands, diagnostics, help, highlights, icons,
  jumps, keymaps, marks, man, quickfix, resume, undo, LSP symbols +
  workspace symbols.
- **Git** (`<leader>g*`) — branches, status, stash, diff hunks, log-file,
  log-line, `gg` lazygit, `gl` lazygit log, `gB` browse on the forge.
- **LSP** — `gd`/`gD`/`gI`/`gy` goto pickers, `<leader>sr` references.
- **Misc** — zen (`<leader>z`), zoom (`<leader>Z`), scratch (`<leader>.`),
  notifications (`<leader>n`), buffer delete (`<leader>bd`), file rename
  (`<leader>cR`), terminal (`<C-/>`), `]]`/`[[` word references.
- **Toggles** (`<leader>u*`) — spell, wrap, relative number, diagnostics,
  line numbers, conceal, treesitter, inlay hints, indent guides, dim.

## Custom plugin-inventory picker (`<leader>sp`)

`picker/plugins.lua` is a hand-written picker over `vim.pack.get()`: fuzzy
search by name/src with a preview of source, path, on-disk size (batched
`du`, `.git` excluded), rev/branches/tags — and a load-state dot computed by
inspecting `vim.fn.getscriptinfo()` and `package.loaded`, because vim.pack's
`active` flag can't distinguish "loaded" from "registered with
`load = false`". Confirm opens the plugin dir in [oil](oil-nvim.md); `<a-b>`
opens the repo URL, `<c-y>` yanks the path. This is the introspection
counterpart to the [dispatcher](../architecture.md)'s lazy loading.

## Debug globals

`_G.dd` (inspect), `_G.bt` (backtrace); `vim.print` is overridden to `dd`,
so `:=` pretty-prints via snacks.

## Source

- Spec tree: [`home/nvim/.config/nvim/lua/plugins/snacks/`](../../../home/nvim/.config/nvim/lua/plugins/snacks/)
- Upstream: <https://github.com/folke/snacks.nvim>
