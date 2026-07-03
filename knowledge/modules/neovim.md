---
type: Darwin Module
title: Neovim
description: Installs Neovim plus every LSP/linter/formatter binary on the global PATH; the Lua config itself is stow-deployed and documented in the nvim knowledge area.
resource: modules/darwin/neovim.nix
tags: [darwin-module]
timestamp: '2026-07-02T00:00:00-07:00'
---

Provisions the editor. nix-darwin has no `programs.neovim`, so there is no
wrapper: Neovim and all its supporting binaries (language servers, linters,
formatters — gopls, vtsls, lua-language-server, efm-langserver, shellcheck,
stylua, …) are plain system packages on the global PATH.

The configuration itself is a Lua tree deployed via the
[stow tree pattern](../patterns/stow-tree.md) from `home/nvim/` and
documented as its own knowledge area: **[nvim](../nvim/index.md)** —
[architecture](../nvim/architecture.md) (native vim.pack + lazy dispatcher),
[LSP & formatting](../nvim/lsp.md), [keymaps](../nvim/keymaps.md),
[options](../nvim/options.md), and a [per-plugin
catalog](../nvim/plugins/index.md).

Follows the [module option pattern](../patterns/module-option-pattern.md), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/neovim.nix`](../../modules/darwin/neovim.nix)
- Options under: `kriswill.neovim`
- Stow package: [`home/nvim/`](../../home/nvim/) — see the [stow tree pattern](../patterns/stow-tree.md)
