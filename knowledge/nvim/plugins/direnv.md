---
type: Neovim Plugin
title: direnv.nvim
description: direnv integration — manual allow/deny/reload under <leader>fe, statusline indicator, no autoload.
resource: home/nvim/.config/nvim/lua/plugins/direnv.lua
tags: [nvim-plugin, tooling]
timestamp: '2026-07-02T00:00:00-07:00'
---

Brings `.envrc` environments into Neovim. Autoload is deliberately **off**
(`autoload_direnv = false`) — environments are activated explicitly via the
`<leader>fe` namespace (which-key group "dir[e]nv"): `fea` allow, `fed` deny,
`fer` reload, `fee` edit. A statusline indicator (custom glyph) shows the
active state. Pairs with the repo-wide direnv workflow (the dev shell is
entered via direnv, not `nix develop` — see the [direnv darwin
module](../../modules/direnv.md)).

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/direnv.lua`](../../../home/nvim/.config/nvim/lua/plugins/direnv.lua)
- Upstream: <https://github.com/NotAShelf/direnv.nvim>
