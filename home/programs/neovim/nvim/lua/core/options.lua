vim.g.mapleader = " "
-- vim.wo.wrap = false
-- vim.opt.exrc = true
vim.cmd("syntax on")

do
	local vim_opts = {
		backup = false,
		breakindent = true,
		cmdheight = 0,
		completeopt = { "menuone", "noselect", "noinsert" },
		cursorline = true,
		encoding = "utf-8",
		expandtab = true,
		fileencoding = "utf-8",
		foldcolumn = "0",
		foldenable = true,
		foldexpr = "nvim_treesitter#foldexpr()",
		foldlevel = 99,
		foldlevelstart = 99,
		foldmethod = "expr",
		grepformat = "%f:%l:%c:%m",
		grepprg = "rg --vimgrep",
		hlsearch = true,
		ignorecase = true,
		incsearch = true,
		mouse = "a",
		number = true,
		relativenumber = true,
		scrolloff = 8,
		shiftwidth = 2,
		showmode = false,
		showtabline = 2,
		smartcase = true,
		smartindent = true,
		softtabstop = 2,
		splitbelow = true,
		splitright = true,
		swapfile = false,
		tabstop = 2,
		termguicolors = true,
		timeoutlen = 10,
		undofile = true,
		updatetime = 50,
		wrap = false,
	}

	for k, v in pairs(vim_opts) do
		vim.opt[k] = v
	end
end
local opt = vim.opt

-- Session Management
opt.sessionoptions="blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- Disable swap file
opt.swapfile = false

-- Line Numbers
opt.relativenumber = true
opt.number = true

-- Tabs & Indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true
vim.bo.softtabstop = 2

-- Line Wrapping
opt.wrap = false

-- Search Settings
opt.ignorecase = true
opt.smartcase = true

-- Cursor Line
opt.cursorline = true

-- Appearance
opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"
vim.diagnostic.config {
  float = { border = "rounded" }, -- add border to diagnostic popups
}

-- Backspace
opt.backspace = "indent,eol,start"

-- Clipboard
opt.clipboard:append("unnamedplus")

-- Split Windows
opt.splitright = true
opt.splitbelow = true

-- Consider - as part of keyword
opt.iskeyword:append("-")

-- Disable the mouse while in nvim
-- opt.mouse = ""

-- Folding
opt.foldlevel = 20
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()" -- Utilize Treesitter folds
