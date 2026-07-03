# nvim

The Neovim configuration — plugins, keymaps, LSP, and options for the Lua
config tree under `home/nvim/`. It is deployed via the
[stow tree](../patterns/stow-tree.md) and provisioned (editor binary + every
LSP/linter/formatter tool) by the [neovim darwin
module](../modules/neovim.md). Plugin management is Neovim 0.12's native
`vim.pack` behind a hand-rolled lazy-loading dispatcher (see
[architecture](architecture.md) and the [vim.pack decision
record](../decisions/native-vim-pack.md)); LSP is native
`vim.lsp.config`/`vim.lsp.enable` with formatting routed exclusively through
efm-langserver (see [LSP](lsp.md)).

## Concepts

* [Plugin & Startup Architecture](architecture.md) - How the config boots and how plugins are managed — native vim.pack behind a hand-rolled trigger dispatcher (now/later/ft/cmd/keys), with explicit load order.
* [Filetype Detection & ftplugins](filetypes.md) - Custom filetype registrations plus shebang-based detection for extensionless scripts; per-filetype tweaks under ftplugin/.
* [Keymap Topology](keymaps.md) - Space-leader keymap layout — which namespace lives where, core non-leader maps, and which plugin owns each group.
* [LSP & Formatting](lsp.md) - Native vim.lsp.config/enable with one file per server, efm-langserver as the single formatting/linting authority, format-on-save filtered to efm.
* [Editor Options](options.md) - Core vim.opt settings — 2-space indent defaults, treesitter folds, hidden cmdline, system clipboard, transparency-friendly UI.

## Subdirectories

* [plugins](plugins/index.md) - Catalog of every Neovim plugin — one doc per spec file under `lua/plugins/`.
