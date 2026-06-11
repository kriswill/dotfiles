return {
  src = "https://github.com/lewis6991/gitsigns.nvim",
  trigger = "now",
  setup = function()
    require("gitsigns").setup()
  end,
}
