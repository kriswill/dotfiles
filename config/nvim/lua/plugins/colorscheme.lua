-- https://github.com/rebelot/kanagawa.nvim
return {
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    config = function()
      local kanagawa = require("kanagawa")
      kanagawa.setup({
        compile = false,
        transparent = true,
        colors = {
          theme = {
            all = {
              ui = {
                bg_gutter = "none",
                float = { bg = "none" },
              },
            },
          },
        },
        overrides = function(colors)
          return {
            CursorLine = { bg = colors.palette.sumiInk2 },
            ["@markup.link.url.markdown_inline"] = { link = "Special" }, -- (url)
            ["@markup.link.label.markdown_inline"] = { link = "WarningMsg" }, -- [label]
            ["@markup.italic.markdown_inline"] = { link = "Exception" }, -- *italic*
            ["@markup.raw.markdown_inline"] = { link = "String" }, -- `code`
            ["@markup.list.markdown"] = { link = "Function" }, -- + list
            ["@markup.quote.markdown"] = { link = "Error" }, -- > blockcode
          }
        end,
      })
      kanagawa.load("wave")
    end,
  },
  {
    "nvim-zh/colorful-winsep.nvim",
    lazy = false,
    config = function()
      local colors = require("kanagawa.colors").setup()
      _G.kanagawa_colors = colors
      require("colorful-winsep").setup({
        hi = {
          fg = colors.palette.oniViolet,
          bg = "none",
        },
      })
    end,
    event = { "winleave" },
  },
}
