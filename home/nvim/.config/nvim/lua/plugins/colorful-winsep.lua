return {
  src = "https://github.com/nvim-zh/colorful-winsep.nvim",
  trigger = "now",
  setup = function()
    local colors = require("kanagawa.colors").setup()
    _G.kanagawa_colors = colors
    require("colorful-winsep").setup({
      hi = {
        fg = colors.palette.oniViolet,
        bg = "none",
      },
    })
  end,
}
