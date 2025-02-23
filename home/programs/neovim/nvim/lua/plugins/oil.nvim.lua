return {
  "stevearc/oil.nvim",
  --@module 'oil'
  --@type oil.SetupOpts
  opts = {},
  dependencies = {{ "echasnovski/mini.icons", opts = {} }},
  lazy = false,
  keys = {
    { "-", "<cmd>Oil --float<CR>", mode = "n", desc = "Open Parent Dir" },
  },
}
