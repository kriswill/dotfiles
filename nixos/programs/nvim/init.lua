vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- set statusline colors
vim.cmd([[
  hi VertSplit guifg=#151515
  hi User1 guifg=#999999 guibg=#151515
  hi User2 guifg=#eea040 guibg=#151515
  hi User3 guifg=#0072ff guibg=#151515
  hi User4 guifg=#ffffff guibg=#151515
  hi User5 guifg=#777777 guibg=#151515
]])

-- set statusline
vim.o.statusline = table.concat({
  "%1* %n %*",       -- buffer number
  "%3* %y %*",       -- file type
  -- "%4* %<%F %*",  -- full path
  "%4* %<%f %*",     -- file name
  "%2* %m %*",       -- modified flag
  "%1* %= %5l %*",   -- current line
  "%2* / %L %*",     -- total lines
  "%1* %4v %*",      -- virtual column number
  "%2* 0x%04B %*",   -- character under cursor
  "%5* %{&ff} %*",   -- file format
})

-- require("which-key").setup({
--   keys = { "<leader>", "<localleader>" },
-- })


require('nvim-treesitter.configs').setup {
	highlight = {
		enable = true
  }
}

-- Enable telescope extensions, if they are installed
pcall(require('telescope').load_extension, 'fzf')
pcall(require('telescope').load_extension, 'ui-select')

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})