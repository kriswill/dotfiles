local opt = vim.opt

-- Session Management
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- Disable swap file
opt.swapfile = false

-- Line Numbers
opt.relativenumber = true
opt.number = true

-- Tabs & Indentation
opt.tabstop = 2 -- spaces shown per tab character
opt.softtabstop = 2 -- spaces to insert when hitting tab
opt.shiftwidth = 2
opt.expandtab = true
opt.smarttab = true
opt.smartindent = true
opt.autoindent = true -- keep indentation from previous line
opt.breakindent = true

-- Line Wrapping
opt.wrap = false

-- Search Settings
opt.ignorecase = true -- case-insensitive unless \C or one or more CAP letters
opt.smartcase = true

-- Appearance
opt.cursorline = true -- Highlight the line the cursor is on
opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "no" -- "yes" to always preserve column
vim.diagnostic.config({
  float = { border = "rounded" }, -- add border to diagnostic popups
})

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

-- -- Display placeholders for invisible characters
-- opt.list = true
-- -- opt.listchars = [[trail:·,tab:⇒\ ]]
-- opt.listchars = [[trail:·]]

-- buffer lines to preserve to keep above and below the cursor while scrolling
opt.scrolloff = 5

-- Folding
opt.foldlevel = 20
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()" -- Utilize Treesitter folds

-- hide line for commands until you start a command
opt.cmdheight = 0
