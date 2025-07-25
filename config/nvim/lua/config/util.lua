local util = {}

-- supply any lua table to have it pretty-print to a new buffer
util.PrintTableToBuffer = function(tbl)
  local str = vim.inspect(tbl)
  local lines = vim.split(str, "\n")
  vim.cmd("new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

util.is_present = function(bin) return vim.fn.executable(bin) == 1 end

util.get_user_config = function(key, default)
  local status_ok, user = pcall(require, "user")
  if not status_ok then
    return default
  end

  local user_config = user[key]
  if user_config == nil then
    return default
  end
  return user_config
end

util.get_root_dir = function()
  local bufname = vim.fn.expand("%:p")
  if vim.fn.filereadable(bufname) == 0 then
    return
  end

  local parent = vim.fn.fnamemodify(bufname, ":h")
  local git_root = vim.fn.systemlist("git -C " .. parent .. " rev-parse --show-toplevel")
  if #git_root > 0 and git_root[1] ~= "" then
    return git_root[1]
  else
    return parent
  end
end

return util
