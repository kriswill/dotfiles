---
type: Neovim Plugin
title: which-key.nvim
description: Keymap popup (helix preset, 300 ms) that names the leader namespaces; <leader>? shows buffer-local maps.
resource: home/nvim/.config/nvim/lua/plugins/which-key.lua
tags: [nvim-plugin, keymaps, ui]
timestamp: '2026-07-02T00:00:00-07:00'
---

Names every leader namespace so the [keymap topology](../keymaps.md) is
discoverable in-editor. Helix-style preset, 300 ms delay, uncapped popup
height, spelling plugin off, custom nerd-font breadcrumb/group glyphs.
Deferred to `UIEnter` (`trigger = "later"`).

The `spec` table declares the group labels ([F]ile, [g]it → *[g]o*, [s]earch,
[u]i, dir[e]nv, [B]uffer, …). A few declared groups (test, replace,
package-info, diagnostics/quickfix) have no maps bound today — see the
quirks list in [keymaps](../keymaps.md). Defines one map itself:
`<leader>?` → buffer-local keymap popup.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/which-key.lua`](../../../home/nvim/.config/nvim/lua/plugins/which-key.lua)
- Upstream: [https://github.com/folke/which-key.nvim](https://github.com/folke/which-key.nvim)
