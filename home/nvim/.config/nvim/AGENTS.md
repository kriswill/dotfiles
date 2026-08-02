# Agent Guidelines — Neovim Configuration

Lua configuration for Neovim, part of the dotfiles stow tree: `home/nvim/`
mirrors `$HOME`, so this directory is deployed as `~/.config/nvim` (symlinks
into the live repo — edits apply without a rebuild). The editor and every
LSP/linter/formatter binary are provisioned by the module twins
`modules/darwin/neovim.nix` ↔ `modules/nixos/neovim.nix`; adding a tool means
adding it to BOTH package lists.

## Code Style - Lua

**Formatter:** stylua (`.stylua.toml` in this directory)

- `indent_width = 2` (spaces)
- `collapse_simple_statement = "FunctionOnly"`
- `sort_requires.enabled = true`

## Structure

- Entry: `init.lua` → `require("config")`; `lua/config/init.lua` loads the
  core modules in explicit order (util → options → filetypes → keymaps →
  multiplexer → transparency → pack → plugins → functions → lsp)
- Core config: `lua/config/` (options, keymaps, filetype detection, LSP,
  multiplexer navigation, transparency)
- Plugins: `lua/plugins/` — one spec file per plugin. NOT lazy.nvim: specs
  feed Neovim 0.12's native `vim.pack` through the dispatcher in
  `lua/config/pack.lua`; a spec is `{ src, name?, version?, trigger =
  "now"|"later"|{ft|cmd|keys=…}, deps = {…}, setup = function() end }`
- Per-filetype tweaks: `ftplugin/<ft>.lua`

## LSP & Formatting

Native `vim.lsp.config` / `vim.lsp.enable` (Neovim 0.11+), wired in
`lua/config/lsp.lua`. One file per server under `lsp/<name>.lua` —
`vim.lsp.enable("<name>")` resolves that file automatically. Formatting and
linting route exclusively through efm-langserver (`lsp/efm.lua`).

**Keep `LANGUAGES.md` (this directory) current:** it is the snapshot matrix of
every filetype's LSP, linter, and formatter and the binary that provides it —
update it whenever a server or tool is added, removed, or rerouted.

## Deeper References (repo root)

- `knowledge/nvim/` — catalog + concept docs: plugin/startup architecture,
  keymap topology, LSP, multiplexer navigation, one doc per plugin spec.
  After adding or removing a plugin, follow the `knowledge-bundle` procedure
  (`okf scaffold` + `okf index`).
- `docs/neovim-testing.md` — driving a real Neovide session to verify UI
  changes; headless `nvim --headless` can't confirm popups actually paint.
