---
type: Neovim Plugin
title: efmls-configs-nvim
description: Prebuilt linter/formatter tool definitions for efm-langserver — a data dependency of lsp/efm.lua, no setup of its own.
resource: home/nvim/.config/nvim/lua/plugins/efmls-configs-nvim.lua
tags: [nvim-plugin, lsp, formatting]
timestamp: '2026-07-02T00:00:00-07:00'
---

Bare spec with no `setup` — it only needs to be on the runtimepath before
`lsp/efm.lua` is evaluated, which requires its
`efmls-configs.{linters,formatters}.*` modules. The interesting configuration
(which tools run for which filetype, and the overrides where the shipped
modules fall short) lives in [LSP & Formatting](../lsp.md) and the
[efm decision record](../../decisions/efm-umbrella-formatting.md).

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/efmls-configs-nvim.lua`](../../../home/nvim/.config/nvim/lua/plugins/efmls-configs-nvim.lua)
- Upstream: <https://github.com/creativenull/efmls-configs-nvim>
