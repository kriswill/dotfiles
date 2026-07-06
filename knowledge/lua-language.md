---
type: Reference
title: Lua Language
description: 'Lua — the small embeddable scripting language, used here in its Lua 5.1/LuaJIT dialect exclusively as the Neovim configuration language, formatted by stylua and served by lua-ls + lazydev.'
tags: [lua, language]
timestamp: '2026-07-04T00:00:00-07:00'
---

[Lua](https://www.lua.org/manual/5.1/) is a small, embeddable, dynamically
typed scripting language. In this repository it appears in exactly one
habitat: Neovim, which embeds LuaJIT, so the working dialect is Lua 5.1.

## How this repo uses it

**All Lua is the Neovim config** — `init.lua` is the one-liner
`require("config")`, and everything under
`home/nvim/.config/nvim/lua/{config,plugins}/` is plain Lua on nightly
Neovim, including the hand-rolled `vim.pack` trigger dispatcher (see
[Plugin & Startup Architecture](nvim/architecture.md)). There is no Lua
outside the editor (no hammerspoon, no awesome).

**Formatting** is stylua via efm, configured in the config tree's own
`.stylua.toml`: 2-space indent, `collapse_simple_statement =
"FunctionOnly"`, sorted requires. lua-ls itself never formats —
format-on-save is filtered to efm as the single formatting authority
([nvim LSP](nvim/lsp.md)).

**Language server** is lua-ls with its workspace library set to all Neovim
runtime files, paired with [lazydev](nvim/plugins/lazydev-nvim.md) so
editing the config gets plugin-and-API-aware completion.

## Citations

- [Lua 5.1 Reference Manual](https://www.lua.org/manual/5.1/) — the dialect
  Neovim's LuaJIT implements
- [Neovim Lua guide](https://neovim.io/doc/user/lua-guide.html)
