-- snacks/keymaps/init.lua
local files = require("plugins.snacks.keymaps.files")
local git = require("plugins.snacks.keymaps.git")
local search = require("plugins.snacks.keymaps.search")
local lsp = require("plugins.snacks.keymaps.lsp")
local misc = require("plugins.snacks.keymaps.misc")

-- Combine all keymap tables
local keymaps = {}
vim.list_extend(keymaps, files)
vim.list_extend(keymaps, git)
vim.list_extend(keymaps, search)
vim.list_extend(keymaps, lsp)
vim.list_extend(keymaps, misc)

return keymaps