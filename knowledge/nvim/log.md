# Log

## 2026-07-28

- **Update** — [multiplexer navigation](multiplexer.md): recorded that
  `<C-Space>` is unreachable under tmux for the same reason as under herdr —
  `set -g prefix C-space` claims the chord before any root-table binding is
  consulted, so tmux's own `bind-key -n 'C-Space' … send-keys C-Space`
  forwarding half never runs either. The `n` motion stays correct for a bare
  terminal or a rebound prefix.

- **Update** — [multiplexer navigation](multiplexer.md) corrected against the
  code after a review of the landing commit. The doc had claimed a zoomed pane
  is never left by any of the six motions; `disable_when_zoomed` gates the four
  directional keys only, and `<C-\>` / `<C-Space>` deliberately do escape a
  zoom (they are explicit "go elsewhere" commands — gating them makes both dead
  keys in a zoomed single-window nvim). Also documents what the fixes changed:
  synchronous hand-offs whose exit status is believed, `FocusGained` refreshing
  the last-active flag, the float-proof `winnr(dir)` edge test and cmdwin guard,
  server-resolved `--current` on the herdr backend, validated
  `vim.g.multiplexer`, the new insert- and terminal-mode semantics, and the fact
  that `<C-Space>` only reaches nvim in a bare terminal because both
  multiplexers bind `ctrl+space` as their prefix.

- **Creation** — [multiplexer navigation](multiplexer.md): `<C-h/j/k/l>` split
  ↔ pane navigation moved from the `nvim-tmux-navigation` plugin into
  `lua/config/multiplexer.lua`, a local module with tmux and herdr backends
  detected from `$TMUX` / `$HERDR_PANE_ID`. Same edge-detection behaviour, one
  fewer plugin. `knowledge/nvim/plugins/tmux.md` deleted with it; see the
  [decision record](../decisions/vim-aware-pane-navigation.md).

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
