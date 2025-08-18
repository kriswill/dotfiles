return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    local configs = require("nvim-treesitter.configs")

    configs.setup({
      ensure_installed = {
        "bash",
        "c",
        "cpp",
        "go",
        "html",
        "javascript",
        "latex",
        "lua",
        "markdown",
        "nix",
        "scss",
        "svelte",
        "typst",
        "vim",
        "vimdoc",
        "vue",
      },
      auto_install = true,
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<Enter>",
          node_incremental = "<Enter>",
          node_decremental = "<Backspace>",
          scope_incremental = false,
        },
      },
    })
  end,
}
