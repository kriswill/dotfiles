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
            symbols = {
              modified = "  ",
              readonly = "  ",
              unnamed = "  ",
            },
          },
          { "fancy_diagnostics", sources = { "nvim_lsp" }, symbols = { error = " ", warn = " ", info = " " } },
          { "fancy_searchcount" },
        },
        lualine_x = {
          { "fancy_branch", icon = { "", color = { fg = "#fc5603" } } },
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
