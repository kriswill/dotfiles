-- snacks.nvim — top-level spec; helpers live under lua/plugins/snacks/
return {
  src = "https://github.com/folke/snacks.nvim",
  trigger = "now",
  setup = function()
    local dashboard = require("plugins.snacks.dashboard")
    local keymaps = require("plugins.snacks.keymaps")
    local picker = require("plugins.snacks.picker")
    local setup_toggles = require("plugins.snacks.config.toggles")
    local setup_globals = require("plugins.snacks.config.globals")

    require("snacks").setup({
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
    })

    -- Keymaps (previously lazy.nvim's `keys =`)
    for _, k in ipairs(keymaps) do
      local lhs = k[1]
      local rhs = k[2]
      local mode = k.mode or "n"
      vim.keymap.set(mode, lhs, rhs, { desc = k.desc, silent = true })
    end

    -- Debug globals + toggle mappings (was an `init` + VeryLazy autocmd)
    setup_globals()
    setup_toggles()
  end,
}
