-- nvim-treesitter-textobjects `main` branch. Keymaps are set explicitly
-- via require(...).select_textobject / .swap_* rather than a keymaps table.
return {
  src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects",
  trigger = "now",
  setup = function()
    require("nvim-treesitter-textobjects").setup({
      select = {
        lookahead = true,
        selection_modes = {
          ["@parameter.outer"] = "v",
          ["@function.outer"] = "V",
          ["@class.outer"] = "<c-v>",
        },
        include_surrounding_whitespace = true,
      },
      move = {
        set_jumps = true,
      },
    })

    local select = function(query, group)
      return function()
        require("nvim-treesitter-textobjects.select").select_textobject(query, group or "textobjects")
      end
    end
    vim.keymap.set({ "x", "o" }, "af", select("@function.outer"), { desc = "a function" })
    vim.keymap.set({ "x", "o" }, "if", select("@function.inner"), { desc = "inner function" })
    vim.keymap.set({ "x", "o" }, "ac", select("@class.outer"), { desc = "a class" })
    vim.keymap.set({ "x", "o" }, "ic", select("@class.inner"), { desc = "inner class" })
    vim.keymap.set({ "x", "o" }, "ao", select("@comment.outer"), { desc = "a comment" })
    vim.keymap.set({ "x", "o" }, "as", select("@local.scope", "locals"), { desc = "a scope" })

    vim.keymap.set("n", "<leader>a", function()
      require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
    end, { desc = "Swap with next parameter" })
    vim.keymap.set("n", "<leader>A", function()
      require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner")
    end, { desc = "Swap with previous parameter" })
  end,
}
