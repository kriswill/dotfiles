---
type: Decision
title: Manage Neovim Plugins with Native vim.pack
description: Drop lazy.nvim for Neovim 0.12's built-in vim.pack, recreating lazy-loading with a ~160-line dispatcher instead of a third-party plugin manager.
tags: [nvim, plugins]
timestamp: '2026-07-02T00:00:00-07:00'
---

**Status:** active. **Where:** [Plugin & Startup Architecture](../nvim/architecture.md).

## Context

Neovim 0.12 shipped a native plugin manager, `vim.pack`. LSP in this config
was already native (`vim.lsp.config`/`enable` — no nvim-lspconfig, no
mason), which left lazy.nvim as the last third-party orchestrator, carrying
a bootstrap step and a lockfile. But `vim.pack` is deliberately minimal: no
`event`/`ft`/`cmd`/`keys` lazy-loading, no `build` hooks, no lockfile, load
order = spec-list order.

## Decision

Migrate to `vim.pack` (branch `lazynvim-to-pack`, PR #4) and recreate just
the lazy-loading actually used, as a thin dispatcher in
`lua/config/pack.lua`: `now` / `later` (UIEnter) / `ft` / `cmd` / `keys`
triggers over `vim.pack.add(..., { load = false })` + stub
commands/keymaps. Plugin files return `{ src, version?, trigger, deps,
setup }` specs, ordered explicitly in `lua/config/plugins.lua`. Build hooks
became `PackChanged` autocmds (`:TSUpdate` for
[treesitter](../nvim/plugins/treesitter.md)); dotted spec filenames were
renamed hyphenated so `require` doesn't treat them as paths. A custom
[snacks picker](../nvim/plugins/snacks.md) (`<leader>sp`) provides the
plugin-inventory UI lazy.nvim used to offer, including a load-state check
that vim.pack's own `active` flag can't answer.

## Consequences

- No bootstrap, no lockfile, one less moving part; the dispatcher is ~160
  lines of repo-owned code.
- Version pinning is opt-in per spec (`version =` branch/tag/commit/range);
  only [blink.cmp](../nvim/plugins/blink-cmp.md) pins today — everything
  else tracks upstream default branches on `vim.pack.update()`.
- Lazy-loading semantics are hand-rolled: quirks like FileType-already-fired
  (files opened from argv) are handled in the dispatcher and must be
  maintained here.

## Citations

- Commits `267dd6f` (migration), `6148abd` (PR #4 merge), `2e76ea3`
  (lazy-lock.json removal), `e1b89c6` (plugin-inventory picker)
- [NVIM_PACK.md migration notes (removed in `a6f3bdf`)](https://github.com/kriswill/dotfiles/blob/da708a24561e44dbf0006207a9ecbb3b3dc93e3d/NVIM_PACK.md)
