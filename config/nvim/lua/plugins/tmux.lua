return {
  "alexghergh/nvim-tmux-navigation",
  config = function()
    require("nvim-tmux-navigation").setup({
      disable_when_zoomed = true, -- defaults to false
      keybindings = {
        left = "<C-h>",
        down = "<C-j>",
        up = "<C-k>",
        right = "<C-l>",
        last_active = "<C-\\>",
        next = "<C-Space>",
      },
    })
    -- Terminal mode window navigation
    vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Move to left window from terminal" })
    vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], { desc = "Move to window below from terminal" })
    vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Move to window above from terminal" })
    vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Move to right window from terminal" })
    vim.keymap.set("t", "<M-Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
  end,
}
