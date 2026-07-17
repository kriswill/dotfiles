# Log

## 2026-07-02

- **Update** — Svelte LSP wired into Neovim: `lsp/svelte.lua`
  (`svelteserver --stdio`), enabled in `lua/config/lsp.lua`, and
  `svelte-language-server` added to the [neovim module](../modules/neovim.md)'s
  lsp-servers. [nvim/lsp](lsp.md) and `LANGUAGES.md` updated —
  svelteserver owns `.svelte` buffers (vtsls stays on plain js/ts); svelte
  has no efm formatter so format-on-save is a no-op there. Verified headless:
  attach with correct root + published diagnostics.

- **Creation** — New `nvim/` knowledge area covering the whole Neovim
  configuration: core concepts ([architecture](architecture.md),
  [options](options.md), [keymaps](keymaps.md),
  [lsp](lsp.md), [filetypes](filetypes.md)) plus a per-plugin
  catalog (23 docs under `nvim/plugins/`). Two decision records added:
  [native vim.pack](../decisions/native-vim-pack.md) and
  [efm umbrella formatting](../decisions/efm-umbrella-formatting.md).
  `okf scaffold` gained a neovim-plugins pass (stubs
  `nvim/plugins/<name>.md` from `lua/plugins/` specs); type registry gained
  `Neovim Plugin` and `Neovim Config`. Source-side staleness spotted while
  authoring was fixed in a sibling commit: `LANGUAGES.md`'s retired
  home-manager module path, `ftplugin/markdown.lua`'s pre-stow `spellfile`
  path, and duplicate `<leader>n` / `<M-B>` keymap definitions.
