return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "helix",
    delay = 300,
    icons = {
      rules = false,
      breadcrumb = " ", -- symbol used in the command line area that shows your active key combo
      separator = "󱦰  ", -- symbol used between a key and it's label
      group = "󰹍 ", -- symbol prepended to a group
    },
    plugins = {
      spelling = {
        enabled = false,
      },
    },
    win = {
      height = {
        max = math.huge,
      },
    },
    spec = {
      {
        mode = { "n", "v" },
        { "<leader>G", group = "Git" },
        { "<leader>N", group = "Package Info" },
        { "<leader>R", group = "Replace" },
        { "<leader>W", group = "Workspace" },
        { "<leader>b", group = "Buffer" },
        { "<leader>f", group = "File" },
        { "<leader>g", group = "Go" },
        { "<leader>l", group = "LSP" },
        { "<leader>n", group = "Gen Annotations" },
        { "<leader>s", group = "Search" },
        { "<leader>t", group = "Test" },
        { "<leader>x", group = "diagnostics/quickfix" },
        { "<leader>u", group = "UI" },
        { "[", group = "prev" },
        { "]", group = "next" },
        { "g", group = "goto" },
      },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
}
