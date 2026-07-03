---
type: Neovim Plugin
title: nvim-dap (debug)
description: DAP debugging with dap-ui and the Go adapter — loads only on first debug keypress; UI auto-opens on launch and closes on exit.
resource: home/nvim/.config/nvim/lua/plugins/debug/
tags: [nvim-plugin, debugging, keymaps]
timestamp: '2026-07-02T00:00:00-07:00'
---

The whole debug stack (nvim-dap + nvim-dap-ui + nvim-dap-go + nvim-nio) is
`keys`-lazy: nothing loads until the first debug keymap is pressed, at which
point the [dispatcher](../architecture.md) swaps the stub maps for the real
ones and re-feeds the key. The spec is a module tree: `init.lua` (setup +
listeners), `keys.lua` (keymap list, doubling as the lazy-load trigger
list), `layout.lua` (dap-ui layout).

## Behavior

- dap-ui opens automatically before attach/launch and closes on
  terminate/exit.
- Layout: REPL + console strip (10 lines) at the bottom; watches / scopes /
  stacks sidebar (40 cols) on the right; code stays in the main window.
- Go debugging via dap-go defaults; breakpoint sign is a custom `⏺`.

## Keymaps

`<leader>dt` toggle UI · `<leader>db` breakpoint · `<leader>dc` continue ·
`<leader>dr` reset UI · `<F5>` continue · `<F10>`/`<F11>`/`<F12>`
over/in/out · `<M-b>` breakpoint · `<M-B>` conditional breakpoint (prompts
for the condition).

## Source

- Spec tree: [`home/nvim/.config/nvim/lua/plugins/debug/`](../../../home/nvim/.config/nvim/lua/plugins/debug/)
- Upstream: <https://github.com/mfussenegger/nvim-dap>
- Bundled deps: <https://github.com/rcarriga/nvim-dap-ui>,
  <https://github.com/leoluz/nvim-dap-go>,
  <https://github.com/nvim-neotest/nvim-nio>
