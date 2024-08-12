require("plugs/alpha")
require("plugs/telescope")
require("plugs/which-key")
require("plugs/lualine")
require("plugs/bufferline")
require("plugs/fidget")

-- null-ls
local null_ls = require("null-ls")
local nb = null_ls.builtins

null_ls.setup({
	on_attach = require("lsp-format").on_attach,
	sources = {
		nb.code_actions.gitsigns,
		nb.code_actions.statix,
		nb.diagnostics.statix,
		nb.diagnostics.yamllint,
		nb.formatting.black.with({
			extra_args = { "--fast" },
		}),
		nb.formatting.nixpkgs_fmt,
		nb.formatting.prettier.with({
			extra_args = { "--no-semi", "--single-quote" },
		}),
		nb.formatting.stylua,
		nb.formatting.yamlfmt,
	},
	updateInInsert = false,
})
map("n", "<leader>cf", "<cmd>lua vim.lsp.buf.format()<cr>", { desc = "Code Format (LSP)" })
require("gitsigns").setup()
require("nvim-autopairs").setup({})
