return {
  "m00qek/baleia.nvim",
  version = "*",
  submodules = false,
  config = function()
    local baleia = require("baleia").setup({})

    -- Command to colorize current buffer on demand
    vim.api.nvim_create_user_command("BaleiaColorize", function() baleia.once(vim.api.nvim_get_current_buf()) end, {})

    -- Optional: auto-colorize specific buffers
    vim.api.nvim_create_autocmd("BufWinEnter", {
      pattern = { "*.log", "*conform*.log" },
      callback = function() baleia.automatically(vim.api.nvim_get_current_buf()) end,
    })
  end,
}
