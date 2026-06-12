return {
  src = "https://github.com/stevearc/oil.nvim",
  trigger = "now",
  deps = {
    { src = "https://github.com/echasnovski/mini.icons" },
  },
  setup = function()
    require("mini.icons").setup({})
    require("oil").setup({
      view_options = {
        show_hidden = true,
      },
    })
    vim.keymap.set("n", "-", "<cmd>Oil --float<CR>", { desc = "Open Parent Dir" })
  end,
}
