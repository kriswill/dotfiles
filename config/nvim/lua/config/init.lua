-- Enable the Lua loader byte-compilation cache.
if vim.loader then
  vim.loader.enable()
end
require("config.util")
require("config.options")
require("config.keymaps")
require("config.transparency")
require("config.pack")
require("config.plugins")
require("config.functions")
require("config.lsp")
