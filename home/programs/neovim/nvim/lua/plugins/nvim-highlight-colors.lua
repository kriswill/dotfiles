return {
	"brenoprata10/nvim-highlight-colors",
	event = "VeryLazy",
	config = function()
		local c = require("nvim-highlight-colors")
		c.setup({})
    vim.keymap.set("n", "<leader>tc", function() c.toggle() end, { desc = "Toggle Color Highlights" })
	end,
}
