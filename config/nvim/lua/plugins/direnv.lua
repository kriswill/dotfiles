return {
  "NotAShelf/direnv.nvim",
  config = function()
    require("direnv").setup({
      -- bin = "direnv",
      autoload_direnv = false,

      statusline = {
        enabled = true,
        icon = "󱚟",
      },

      keybindings = {
        allow = "<Leader>fea",
        deny = "<Leader>fed",
        reload = "<Leader>fer",
        edit = "<Leader>fee",
      },

      notifications = {
        level = vim.log.levels.INFO,
        silent_autoload = true,
      },
    })
  end,
}
