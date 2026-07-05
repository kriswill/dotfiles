---
type: Neovim Config
title: LSP & Formatting
description: Native vim.lsp.config/enable with one file per server, efm-langserver as the single formatting/linting authority, format-on-save filtered to efm.
resource: home/nvim/.config/nvim/lua/config/lsp.lua
tags: [nvim, lsp]
timestamp: '2026-07-02T00:00:00-07:00'
---

LSP is fully native — Neovim 0.11+'s `vim.lsp.config` format with one file
per server under [`lsp/`](../../home/nvim/.config/nvim/lsp/), activated by
`vim.lsp.enable({...})` in
[`lua/config/lsp.lua`](../../home/nvim/.config/nvim/lua/config/lsp.lua).
There is no nvim-lspconfig and no mason: every server, linter, and formatter
binary is provisioned by the [neovim darwin module](../modules/neovim.md)
onto the global PATH (nix-darwin has no `programs.neovim`, so there is no
wrapper — the binaries are just system packages). The maintained per-language
matrix lives in
[`LANGUAGES.md`](../../home/nvim/.config/nvim/LANGUAGES.md).

## Enabled servers

bash · buf_ls · css · dockerfile · efm · gopls · html · json · luals ·
nil_ls · rust_analyzer · svelte · tofu_ls · vtsls · yaml.
`lsp/terraform.lua` exists
but is commented out — [tofu_ls](https://github.com/opentofu/tofu-ls)
supersedes it for the same filetypes. Notable per-server choices:

- **bash** ([Bash Language](../bash-language.md)) — bashls' built-in
  shellcheck is disabled (`shellcheckPath = ""`) so efm's shellcheck
  doesn't produce duplicate `SC####` diagnostics.
- **json/yaml** — schemas come from [schemastore](plugins/schemastore.md)
  (`require("schemastore").yaml.schemas()`).
- **luals** ([Lua Language](../lua-language.md)) — workspace library set to
  all runtime files; pairs with [lazydev](plugins/lazydev-nvim.md) for
  config development.
- **nil_ls** — `autoEvalInputs = false` ("generates too many issues"),
  formats with nixfmt, ignores `unused_binding`/`unused_with` (dendritic
  modules legitimately keep unused args).
- **svelte** ([Svelte Language](../svelte-language.md)) — `svelteserver`
  (from `svelte-language-server`) owns `.svelte` files, including their
  embedded JS/TS/CSS; vtsls stays scoped to plain js/ts filetypes so the
  two never fight over a buffer.
- **vtsls** ([TypeScript Language](../typescript-language.md)) — workspace
  TypeScript SDK preferred, inlay hints on (parameter names for literals
  only), server-side fuzzy completion.

`window/showMessage` INFO-level messages are dropped; the rest route to
`vim.notify`.

## efm: the single formatting/linting authority

efm-langserver is an umbrella server that runs CLI linters and formatters as
LSP (see the [decision record](../decisions/efm-umbrella-formatting.md)).
Tool definitions come from [efmls-configs-nvim](plugins/efmls-configs-nvim.md),
several extended in-place (yamllint gains `lintFormats` +
`lintIgnoreExitCode`; biome's root markers narrowed to real `biome.json`
files; shfmt anchored on `.editorconfig`) and a few defined inline (yamlfmt,
xmllint, rumdl lint+fmt for [markdown](../markdown-language.md)).

Lint: shellcheck (sh/bash/zsh), hadolint (dockerfile), gitlint (gitcommit),
yamllint, rumdl (markdown). Format: shfmt, yamlfmt, prettier_d (html), biome
(js/ts), stylua (lua), nixfmt (nix), isort+black (python), rustfmt, xmllint
(xml), rumdl.

**Format-on-save** is a `BufWritePre` autocmd filtered to
`client.name == "efm"` — other capable LSPs (vtsls, rust-analyzer, gopls,
lua-ls) never format, so there is exactly one formatting source. The manual
`<leader>cf` map (see [keymaps](keymaps.md)) applies the same filter, so
manual and automatic paths agree. Filetypes not in efm's table (go, proto,
terraform, json, svelte) don't auto-format.

## Filetype plumbing

LSP attach is driven by filetype; custom filetypes and shebang-based
detection for extensionless scripts live in [filetypes](filetypes.md).
LSP progress is surfaced by [fidget](plugins/fidget.md), and goto/references
run through [snacks](plugins/snacks.md) pickers.

## Citations

- Commits `6c1b979` (efm added), `c622be3` (conform removed), `7458862`
  (shell lint moved off bashls)
- [`lsp/efm.lua`](../../home/nvim/.config/nvim/lsp/efm.lua)
- [`LANGUAGES.md`](../../home/nvim/.config/nvim/LANGUAGES.md)
