-- This has to be set before initializing lazy
require("core.lazy").load({
  profiling = {
    loader = false,
    require = true,
  },
})
vim.g.mapleader = " "

-- These modules are not loaded by lazy
require("core.util")
require("core.options")
require("core.keymaps")
require("core.transparency")
