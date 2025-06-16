return {
  "stevearc/oil.nvim",
  --@module 'oil'
  --@type oil.SetupOpts
  opts = {
    view_options = {
      show_hidden = true,
    },
  },
  dependencies = { { "echasnovski/mini.icons", opts = {} } },
  lazy = false,
  keys = {
    { "-", "<cmd>Oil --float<CR>", mode = "n", desc = "Open Parent Dir" },
  },
}
