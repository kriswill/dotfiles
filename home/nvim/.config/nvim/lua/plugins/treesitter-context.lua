return {
  src = "https://github.com/nvim-treesitter/nvim-treesitter-context",
  trigger = "later",
  setup = function()
    require("treesitter-context").setup({ mode = "cursor", max_lines = 3 })
    vim.keymap.set("n", "<leader>ut", function()
      require("treesitter-context").toggle()
    end, { desc = "Toggle Treesitter Context" })
  end,
}
