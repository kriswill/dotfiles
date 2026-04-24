-- https://github.com/rebelot/kanagawa.nvim
return {
  src = "https://github.com/rebelot/kanagawa.nvim",
  trigger = "now",
  setup = function()
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
          ["@markup.link.url.markdown_inline"] = { link = "Special" },
          ["@markup.link.label.markdown_inline"] = { link = "WarningMsg" },
          ["@markup.italic.markdown_inline"] = { link = "Exception" },
          ["@markup.raw.markdown_inline"] = { link = "String" },
          ["@markup.list.markdown"] = { link = "Function" },
          ["@markup.quote.markdown"] = { link = "Error" },
        }
      end,
    })
    kanagawa.load("wave")
  end,
}
