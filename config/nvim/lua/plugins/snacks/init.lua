-- snacks/init.lua
local dashboard = require("plugins.snacks.dashboard")
local keymaps = require("plugins.snacks.keymaps")
local picker = require("plugins.snacks.picker")
local setup_toggles = require("plugins.snacks.config.toggles")
local setup_globals = require("plugins.snacks.config.globals")

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  keys = keymaps,
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        -- Setup debug globals
        setup_globals()
        
        -- Setup toggle mappings
        setup_toggles()
      end,
    })
  end,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    explorer = { enabled = true },
    image = { enabled = true },
    indent = { enabled = false },
    input = { enabled = true },
    notifier = { enabled = true, timeout = 3000 },
    picker = picker,
    quickfile = { enabled = true },
    scope = { enabled = false },
    scroll = { enabled = true },
    statuscolumn = { enabled = false },
    words = { enabled = true },
    dashboard = dashboard,
  },
}
