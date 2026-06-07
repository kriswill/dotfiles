return {
  src = "https://github.com/m00qek/baleia.nvim",
  trigger = "now",
  setup = function()
    local baleia = require("baleia").setup({})
    vim.api.nvim_create_user_command("BaleiaColorize", function()
      baleia.once(vim.api.nvim_get_current_buf())
    end, {})
    vim.api.nvim_create_autocmd("BufWinEnter", {
      pattern = { "*.log" },
      callback = function() baleia.automatically(vim.api.nvim_get_current_buf()) end,
    })
  end,
}
