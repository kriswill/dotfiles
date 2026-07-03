---
type: Decision
title: Route All Linting and Formatting Through efm-langserver
description: One umbrella LSP (efm) runs every CLI linter and formatter; format-on-save filters to efm only, so no two tools ever compete over a buffer.
tags: [nvim, lsp, formatting]
timestamp: '2026-07-03T12:00:00-07:00'
---

**Status:** active. **Where:** [LSP & Formatting](../nvim/lsp.md).

## Context

Linting and formatting were spread across mechanisms: conform.nvim for
formatters, per-LSP formatting capabilities (vtsls, rust-analyzer, gopls,
lua-ls all advertise it), and bashls running its own shellcheck. Multiple
formatters competing for the same buffer produce non-deterministic results,
and duplicate diagnostics (two shellchecks) are noise.

## Decision

efm-langserver became the single authority (PR #5, then conform removal):

- CLI linters and formatters are declared once in `lsp/efm.lua`, with tool
  definitions from
  [efmls-configs-nvim](../nvim/plugins/efmls-configs-nvim.md), extended
  in-place where the shipped modules fall short (yamllint output parsing,
  biome root markers, shfmt `.editorconfig` anchoring) and written inline
  where absent (yamlfmt, xmllint, rumdl).
- Format-on-save is a `BufWritePre` autocmd that calls `vim.lsp.buf.format`
  filtered to `client.name == "efm"`; the manual `<leader>cf` map applies
  the identical filter, so manual and automatic formatting can never
  disagree.
- Overlapping built-ins are disabled at the source (bashls
  `shellcheckPath = ""`).
- Markdown later consolidated from markdownlint + prettier_d to rumdl for
  both lint and format.

## Consequences

- Exactly one formatter per filetype, deterministic on save; adding a
  language = one entry in efm's `languages` table plus the binary in the
  [neovim darwin module](../modules/neovim.md).
- Filetypes absent from efm's table (go, proto, terraform, json) do not
  auto-format at all — deliberate, but easy to misread as breakage.
- efm diagnostics arrive under the `efm/` source prefix; the per-language
  matrix is documented in the config's `LANGUAGES.md`.

**Amended 2026-07-03:** the binary now goes in both neovim twins
(`modules/{darwin,nixos}/neovim.nix`) — keep the tool lists in sync.

## Citations

- Commits `6c1b979` (efm added, PR #5 `82c5a5c`), `7458862` (shell lint off
  bashls), `c622be3` (conform removed), `0a1a1ed` (rumdl for markdown)
