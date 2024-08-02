--
-- My super basic Neovim configuration
--
local cmd = vim.cmd
local api = vim.api
local opt = vim.opt
local g = vim.g
local map = api.nvim_set_keymap

g.mapleader = " "
g.maplocalleader = " "

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
	if fg == nil then
		fg = "none"
	end
	if bg == nil then
		bg = "none"
	end
	cmd("hi " .. group .. " guifg=" .. fg .. " guibg=" .. bg)
end

-- set statusline colors
-- hi("VertSplit", "#151515")
-- hi("User1", "#999999", "#151515")
-- hi("User2", "#eea040", "#151515")
-- hi("User3", "#0072ff", "#151515")
-- hi("User4", "#ffffff", "#151515")
-- hi("User5", "#777777", "#151515")
-- set background to transparent - kitty
hi("Normal")

local wkloaded, which_key = pcall(require("which-key"))
if wkloaded then
	which_key.setup({
		keys = { "<leader>", "<localleader>" },
	})
end

require("nvim_comment").setup({
	comment_empty = false,
})

-- Key maps
map("n", "<tab>", "<cmd>bnext<cr>", { desc = "next buffer" })
map("n", "<S-tab>", "<cmd>bprevious<cr>", { desc = "previous buffer" })
map("n", "<A-h>", "<C-w>h", { noremap = true, silent = false, desc = "move to left window" })
map("n", "<A-j>", "<C-w>j", { noremap = true, silent = false, desc = "move to window below" })
map("n", "<A-k>", "<C-w>k", { noremap = true, silent = false, desc = "move to window above" })
map("n", "<A-l>", "<C-w>l", { noremap = true, silent = false, desc = "move to right window" })
map("n", "<C-/>", ":CommentToggle<CR>", { noremap = true, silent = true, desc = "Toggle comments" })
map("v", "<C-/>", ":CommentToggle<CR>", { noremap = true, silent = true, desc = "Toggle comments" })

local hasTreesitter, treesitter = pcall(require, "nvim-treesitter.configs")
if hasTreesitter then
	treesitter.setup({
		highlight = {
			enable = true,
			use_languagetree = true,
		},
		indent = true,
	})
end

-- Enable telescope extensions, if they are installed
pcall(require("telescope").load_extension, "fzf")
pcall(require("telescope").load_extension, "ui-select")

local tbi = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", tbi.find_files, { desc = "Find Files" })
vim.keymap.set("n", "<leader>fg", tbi.live_grep, { desc = "Grep Files" })
vim.keymap.set("n", "<leader>fb", tbi.buffers, { desc = "Find Buffers" })
vim.keymap.set("n", "<leader>fh", tbi.help_tags, { desc = "Find Help" })
