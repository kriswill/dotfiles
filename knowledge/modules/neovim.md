---
type: Dual Module
title: Neovim
description: Installs Neovim plus every LSP/linter/formatter binary on the global PATH; the Lua config itself is stow-deployed and documented in the nvim knowledge area.
resource: modules/darwin/neovim.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Provisions the editor: Neovim and ~45 supporting binaries (language servers,
linters, formatters — gopls, vtsls, lua-language-server, efm-langserver,
shellcheck, stylua, …) go on the global PATH as plain system packages.

The configuration itself is a Lua tree deployed via the
[stow tree pattern](../patterns/stow-tree.md) from `home/nvim/` and
documented as its own knowledge area: **[nvim](../nvim/index.md)** —
[architecture](../nvim/architecture.md) (native vim.pack + lazy dispatcher),
[LSP & formatting](../nvim/lsp.md), [keymaps](../nvim/keymaps.md),
[options](../nvim/options.md), and a [per-plugin
catalog](../nvim/plugins/index.md).

## Twin differences

Darwin has no `programs.neovim` module, so it installs a customized
`pkgs.neovim.override { viAlias; vimAlias; withPython3 = false; withRuby =
false; }` and sets `EDITOR` at `mkOverride 900` (to beat nix-darwin's
`mkDefault "nano"`), plus `VISUAL` and `MANPAGER = "nvim +Man!"`. NixOS uses
snowglobe-lib's minimal `programs.neovim` (enable/viAlias/vimAlias —
snowglobe disables nixpkgs' own module) with `EDITOR = mkDefault "nvim"`.
Known tool-list drift: nixos adds `gcc` (treesitter's `cc`; darwin relies on
Xcode clang), overrides `vtsls` to build against `nodejs-slim_24` (avoiding a
second node in the closure), and omits `nodejs` — delegated to
[node-runtime](node-runtime.md); nixos also does not set `VISUAL`/`MANPAGER`
(unflagged asymmetry). See the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/neovim.nix`](../../modules/darwin/neovim.nix)
- NixOS module: [`modules/nixos/neovim.nix`](../../modules/nixos/neovim.nix)
- Stow package: [`home/nvim/`](../../home/nvim/) — see the [stow tree pattern](../patterns/stow-tree.md)
- Manual: [`docs/neovim-testing.md`](../../docs/neovim-testing.md)
