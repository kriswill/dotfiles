---
type: Neovim Plugin
title: schemastore.nvim
description: JSON/YAML schema catalog consumed by the yaml language server (no setup — a pure data library).
resource: home/nvim/.config/nvim/lua/plugins/schemastore.lua
tags: [nvim-plugin, lsp]
timestamp: '2026-07-02T00:00:00-07:00'
---

Pure data library — the spec has no `setup` at all; it just needs to be on
the runtimepath before [LSP](../lsp.md) starts, which the `"now"` trigger
guarantees. `lsp/yaml.lua` calls `require("schemastore").yaml.schemas()` so
YAML buffers (including the `yaml.docker-compose` filetype from
[filetype detection](../filetypes.md)) validate against their JSON-Schema
automatically.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/schemastore.lua`](../../../home/nvim/.config/nvim/lua/plugins/schemastore.lua)
- Upstream: <https://github.com/b0o/schemastore.nvim>
