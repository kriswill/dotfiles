return {
  src = "https://github.com/nvim-lualine/lualine.nvim",
  trigger = "now",
  deps = {
    { src = "https://github.com/meuter/lualine-so-fancy.nvim" },
  },
  setup = function()
    local kanagawa_theme = require("lualine.themes.kanagawa")
    require("lualine").setup({
      options = {
        theme = kanagawa_theme,
        globalstatus = true,
        icons_enabled = true,
        component_separators = { left = "│", right = "│" },
        section_separators = { left = "", right = "" },
        refresh = {
          statusline = 100,
        },
        disabled_filetypes = {
          statusline = {
            "alfa-nvim",
            "help",
            "neo-tree",
            "Trouble",
            "spectre_panel",
            "toggleterm",
          },
          winbar = {},
        },
      },
      sections = {
        lualine_a = {
          "fancy_mode",
        },
        lualine_b = {},
        lualine_c = {
          {
            "filename",
            path = 1,
            -- Nerd-font glyph reference:  = U+F0F6,  = U+F023,  = U+F10C
            symbols = {
              modified = " \u{F0F6} ",
              readonly = " \u{F023} ",
              unnamed = " \u{F10C} ",
            },
          },
          -- Nerd-font glyph reference:  = U+F057,  = U+F071,  = U+F06A
          { "fancy_diagnostics", sources = { "nvim_lsp" }, symbols = { error = "\u{F057} ", warn = "\u{F071} ", info = "\u{F06A} " } },
          { "fancy_searchcount" },
        },
        lualine_x = {
          -- Nerd-font glyph reference:  = U+F418
          { "fancy_branch", icon = { "\u{F418}", color = { fg = "#fc5603" } } },
          "fancy_diff",
          "fancy_lsp_servers",
          "progress",
        },
        lualine_y = {},
        lualine_z = {},
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_y = {},
        lualine_z = {},
      },
      tabline = {},
    })
  end,
}
