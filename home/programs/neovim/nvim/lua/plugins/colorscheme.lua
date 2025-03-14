return {
  "rebelot/kanagawa.nvim",
  lazy = false,
  config = function ()
    require('kanagawa').setup({
      compile = false,
      transparent = true,
      colors = {
        theme = {
          all = {
            ui = {
              bg_gutter = "none",
            }
          }
        }
      },
      overrides = function (colors)
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
    vim.cmd("colorscheme kanagawa")
  end,
}
