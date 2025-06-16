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
        { "<leader>G", group = "[G]it" },
        { "<leader>N", group = "Package I[n]fo" },
        { "<leader>R", group = "[R]eplace" },
        { "<leader>W", group = "[W]orkspace" },
        { "<leader>b", group = "[B]uffer" },
        { "<leader>f", group = "[F]ile" },
        { "<leader>fe", group = "dir[e]nv" },
        { "<leader>g", group = "[g]o" },
        { "<leader>l", group = "[l]sp" },
        { "<leader>n", group = "Ge[n] Annotations" },
        { "<leader>s", group = "[s]earch" },
        { "<leader>t", group = "[t]est" },
        { "<leader>x", group = "diagnostics/quickfi[x]" },
        { "<leader>u", group = "[u]i" },
        { "[", group = "prev" },
        { "]", group = "next" },
        { "g", group = "[g]oto" },
      },
    },
  },
  keys = {
    {
      "<leader>?",
      function() require("which-key").show({ global = false }) end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
}
