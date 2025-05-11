require("config.util")
require("config.options")
require("config.keymaps")
require("config.transparency")
require("config.lazy")

-- supply any lua table to have it pretty-print to a new buffer
function PrintTableToBuffer(tbl)
  local str = vim.inspect(tbl)
  local lines = vim.split(str, "\n")
  vim.cmd("new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end
