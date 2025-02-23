return {
  "rebelot/kanagawa.nvim",
  lazy = false,
  compile = true,
  build = "KanagawaCompile",
  config = function ()
    require('kanagawa').setup({
      compile = true,
      transparent = true,
      colors = { theme = { all = { ui = { bg_gutter = "none" } } } },
    })
    vim.cmd("colorscheme kanagawa")
  end,
}
