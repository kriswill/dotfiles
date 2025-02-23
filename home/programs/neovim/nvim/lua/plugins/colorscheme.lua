return {
	"rebelot/kanagawa.nvim",
  lazy = false,
	config = function ()
		require('kanagawa').setup({
      compile = true,
			transparent = true, 
      -- theme = "dragon",
		})
		vim.cmd("colorscheme kanagawa")
	end,
  build = function()
    vim.cmd("KanagawaCompile")
  end,
}
