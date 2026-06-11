-- snacks/keymaps/misc.lua
return {
  -- Zen mode
  { "<leader>z", function() Snacks.zen() end, desc = "Toggle Zen Mode" },
  { "<leader>Z", function() Snacks.zen.zoom() end, desc = "Toggle Zoom" },

  -- Scratch buffers
  { "<leader>.", function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
  { "<leader>S", function() Snacks.scratch.select() end, desc = "Select Scratch Buffer" },

  -- Notifications
  { "<leader>n", function() Snacks.notifier.show_history() end, desc = "Notification History" },
  { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications" },

  -- Buffer management
  { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete Buffer" },
  { "<leader>cR", function() Snacks.rename.rename_file() end, desc = "Rename File" },

  -- Terminal
  { "<c-/>", function() Snacks.terminal() end, desc = "Toggle Terminal" },
  { "<c-_>", function() Snacks.terminal() end, desc = "which_key_ignore" },

  -- Word navigation
  { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "Next Reference", mode = { "n", "t" } },
  { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev Reference", mode = { "n", "t" } },

  -- Colorschemes
  { "<leader>uC", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
}

