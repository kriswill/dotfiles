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
        allow = "<Leader>ea",
        deny = "<Leader>ed",
        reload = "<Leader>er",
        edit = "<Leader>ee",
      },

      notifications = {
        level = vim.log.levels.INFO,
        silent_autoload = true,
      },
    })
  end,
}
