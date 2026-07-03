---
type: Neovim Plugin
title: nvim-highlight-colors
description: Inline virtual-text color previews for hex/tailwind values, plus custom palettes — EFG design-system tokens and the full tmux 256-color set.
resource: home/nvim/.config/nvim/lua/plugins/highlight-colors.lua
tags: [nvim-plugin, ui]
timestamp: '2026-07-02T00:00:00-07:00'
---

Renders color swatches as virtual text next to color values (tailwind
classes included), skipping buffers over ~1 MB. The bulk of the spec is
`custom_colors` — named tokens that wouldn't otherwise resolve:

- **EFG design-system tokens** (primary/secondary/premium/alert/common/
  black/white/theme groups), with Lua-pattern-escaped dotted names like
  `primary%.enabled`, so working in that codebase shows real swatches.
- **The full tmux 256-color palette** — `colour0`–`colour255` mapped to
  standard xterm hex values, so editing tmux config (see the
  [tmux module](../../modules/tmux.md)) previews `colourN` references.

## Source

- Spec: [`home/nvim/.config/nvim/lua/plugins/highlight-colors.lua`](../../../home/nvim/.config/nvim/lua/plugins/highlight-colors.lua)
- Upstream: <https://github.com/brenoprata10/nvim-highlight-colors>
