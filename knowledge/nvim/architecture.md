---
type: Neovim Config
title: Plugin & Startup Architecture
description: How the config boots and how plugins are managed — native vim.pack behind a hand-rolled trigger dispatcher (now/later/ft/cmd/keys), with explicit load order.
resource: home/nvim/.config/nvim/lua/config/pack.lua
tags: [nvim, architecture]
timestamp: '2026-07-02T00:00:00-07:00'
---

The whole config is plain Lua on Neovim ≥ 0.12 nightly features: native
`vim.pack` for plugins (no lazy.nvim — see the [decision
record](../decisions/native-vim-pack.md)) and native `vim.lsp` for language
servers (see [LSP](lsp.md)). There is no plugin-manager bootstrap and no
lockfile.

## Boot sequence

`init.lua` is one line — `require("config")` — and
[`lua/config/init.lua`](../../home/nvim/.config/nvim/lua/config/init.lua)
enables the `vim.loader` byte-compilation cache, then loads modules in a
fixed order: `util`, [`options`](options.md), [`filetypes`](filetypes.md),
[`keymaps`](keymaps.md), `transparency`, `pack`, `plugins`, `functions`,
[`lsp`](lsp.md).

## The pack dispatcher (`lua/config/pack.lua`)

A thin wrapper around `vim.pack.add` that restores the lazy-loading lazy.nvim
used to provide. Every file under `lua/plugins/` returns a spec (or list of
specs):

```lua
{ src, name?, version?, trigger = "now"|"later"|{ft|cmd|keys=...},
  deps = { { src = ... } }, setup = function() end }
```

Triggers map to loading strategies:

- `"now"` — `vim.pack.add` + `setup()` immediately.
- `"later"` — added at startup, `setup()` deferred to a one-shot `UIEnter`.
- `{ ft = ... }` — registered with `load = false` (`:packadd!` only);
  `packadd` + `setup()` on first matching `FileType`. Also fires immediately
  if a buffer of that filetype is already open (files passed on the command
  line have their `FileType` event before the autocmd exists).
- `{ cmd = ... }` — stub user commands; first invocation deletes the stubs,
  loads the plugin, and re-runs the command with its args and bang.
- `{ keys = ... }` — stub keymaps; first press deletes the stubs, loads the
  plugin, and re-feeds the key.

`setup()` failures are caught (`pcall`) and surfaced with `vim.notify` rather
than aborting startup. `deps` are added to the `vim.pack.add` list before the
main src.

## Explicit load order (`lua/config/plugins.lua`)

`vim.pack` loads in spec-list order, so
[`lua/config/plugins.lua`](../../home/nvim/.config/nvim/lua/config/plugins.lua)
holds an ordered module list: [colorscheme](plugins/colorscheme.md) first so
palette colors are available to later setups,
[snacks](plugins/snacks.md) early, [treesitter](plugins/treesitter.md) before
[treesitter-textobjects](plugins/treesitter-textobjects.md). A failed
`require` of any spec is caught and notified; the rest still load. Plugin
files use hyphenated names (`oil-nvim.lua`, not `oil.nvim.lua`) because
`require` treats dots as path separators.

## Supporting pieces

- [`lua/config/functions.lua`](../../home/nvim/.config/nvim/lua/config/functions.lua)
  — user commands: `:ReloadConfig` (re-dofiles init.lua after purging
  `plugins.*` from `package.loaded`), `:CopyRelativePath` /
  `:CopyAbsolutePath` / `:CopyFileName`, `:RootDir` (`:lcd` to git root or
  file parent).
- [`lua/config/util.lua`](../../home/nvim/.config/nvim/lua/config/util.lua)
  — small helpers (`PrintTableToBuffer`, `is_present`, `get_root_dir`,
  `get_user_config`).
- [`lua/config/transparency.lua`](../../home/nvim/.config/nvim/lua/config/transparency.lua)
  — clears `bg` on ~25 highlight groups (Normal, floats, Pmenu, sign/fold
  columns, notify groups) so the terminal background shows through; pairs
  with the kanagawa `transparent = true` setting in
  [colorscheme](plugins/colorscheme.md).
- The plugin inventory is introspectable in-editor: `<leader>sp` opens a
  custom snacks picker over `vim.pack.get()` (see [snacks](plugins/snacks.md)).

## Citations

- Commits `267dd6f` (lazy.nvim → vim.pack migration), `1fb733b` (stow
  migration)
- [Removed migration notes `NVIM_PACK.md`](https://github.com/kriswill/dotfiles/blob/da708a24561e44dbf0006207a9ecbb3b3dc93e3d/NVIM_PACK.md)
