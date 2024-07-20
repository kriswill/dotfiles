--
-- My super basic Neovim configuration
--
cmd = vim.cmd
api = vim.api
opt = vim.opt
g = vim.g

g.mapleader = ' '
g.maplocalleader = ' '

cmd([[
  syntax enable
  set smartindent
  set autoindent
  set clipboard+=unnamedplus
  set nocompatible
  set backspace=indent,eol,start
  set termguicolors
  " colorscheme PaperColor  
]])

local options = {
  encoding = "utf-8",
  fileencoding = "utf-8",
  number = true,
  rnu = true,
  cursorline = true,
  expandtab = true,
  tabstop = 2,
  shiftwidth = 2,
  softtabstop = 2,
  scrolloff = 5,
  wrap = true,
  tw = 0,
  splitright = true,
  splitbelow = true,
  showmode = false,
  updatetime = 5000, -- slow down swap file to 5s
  virtualedit = "block",
  mouse = "a",
}

for k, v in pairs(options) do
  opt[k] = v
end

local function hi(group, fg, bg)
  if fg == nil then fg = "none" end
  if bg == nil then bg = "none" end
  cmd("hi " .. group .. " guifg=" .. fg .. " guibg=" .. bg) 
end

-- set statusline colors
hi("VertSplit", "#151515")
hi("User1", "#999999", "#151515")
hi("User2", "#eea040", "#151515")
hi("User3", "#0072ff", "#151515")
hi("User4", "#ffffff", "#151515")
hi("User5", "#777777", "#151515")
-- set background to transparent - kitty
hi("Normal")

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


local hasTreesitter, treesitter = pcall(require, "nvim-treesitter.configs")
if hasTreesitter then
  treesitter.setup {
    highlight = {
      enable = true,
	    use_languagetree = true,
    },
    indent = true,
  }
end

-- Enable telescope extensions, if they are installed
pcall(require('telescope').load_extension, 'fzf')
pcall(require('telescope').load_extension, 'ui-select')

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

