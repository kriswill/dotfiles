local o = vim.opt

-- Session Management
o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- Disable swap file
o.swapfile = false

-- Line Numbers
o.relativenumber = true
o.number = true

-- Tabs & Indentation
o.tabstop = 2 -- spaces shown per tab character
o.softtabstop = 2 -- spaces to insert when hitting tab
o.shiftwidth = 2
o.expandtab = true
o.smarttab = true
o.smartindent = true
o.autoindent = true -- keep indentation from previous line
o.breakindent = true

-- Line Wrapping
o.wrap = false

-- Search Settings
o.ignorecase = true -- case-insensitive unless \C or one or more CAP letters
o.smartcase = true

-- Appearance
o.cursorline = true -- Highlight the line the cursor is on
o.termguicolors = true
o.background = "dark"
o.winborder = "rounded"

-- opt.signcolumn = "no" -- "yes" to always preserve column
vim.diagnostic.config({
  float = { border = "rounded" }, -- add border to diagnostic popups
})

-- Backspace
o.backspace = "indent,eol,start"

-- Clipboard
o.clipboard:append("unnamedplus")

-- Split Windows
o.splitright = true
o.splitbelow = true

-- Consider - as part of keyword
o.iskeyword:append("-")

-- Disable the mouse while in nvim
-- opt.mouse = ""

-- -- Display placeholders for invisible characters
-- opt.list = true
-- -- opt.listchars = [[trail:·,tab:⇒\ ]]
-- opt.listchars = [[trail:·]]

-- buffer lines to preserve to keep above and below the cursor while scrolling
o.scrolloff = 5

-- Folding
o.foldlevel = 20
o.foldmethod = "expr"
o.foldexpr = "nvim_treesitter#foldexpr()" -- Utilize Treesitter folds

-- hide line for commands until you start a command
o.cmdheight = 0
