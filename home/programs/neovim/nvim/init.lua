-- This has to be set before initializing lazy
require("core.lazy").load({
	-- debug = false,
	profiling = {
		loader = false,
		require = true,
	},
})
vim.g.mapleader = " "

-- Initialize lazy with dynamic loading of anything in the plugins directory
require("lazy").setup("plugins", {
	change_detection = {
		enabled = false, -- automatically check for config file changes and reload the ui
		notify = false, -- turn off notifications whenever plugin changes are made
	},
})

-- These modules are not loaded by lazy
require("core.util")
require("core.options")
require("core.keymaps")
