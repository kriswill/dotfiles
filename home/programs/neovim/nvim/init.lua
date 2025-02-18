-- This has to be set before initializing lazy
require("core.lazy").load({
	profiling = {
		loader = false,
		require = true,
	},
	plugins = {
		change_detection = {
			enabled = false, -- automatically check for config file changes and reload the ui
			notify = false, -- turn off notifications whenever plugin changes are made
		},
	},
})
vim.g.mapleader = " "

-- These modules are not loaded by lazy
require("core.util")
require("core.options")
require("core.keymaps")
