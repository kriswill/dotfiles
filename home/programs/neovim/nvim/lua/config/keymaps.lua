vim.g.mapleader = " "                                   -- change leader to a space
vim.g.maplocalleader = " "                              -- change localleader to a space

local keymap = vim.keymap.set

-- General keymaps
keymap("i", "jk", "<ESC>") -- Exit insert mode with jk
keymap("i", "ii", "<ESC>") -- Exit insert mode with ii
-- keymap("n", "<leader>wq", ":wq<CR>") -- save and quit
-- keymap("n", "<leader>qq", ":q!<CR>") -- quit without saving
-- keymap("n", "<leader>ww", ":w<CR>") -- save
keymap("n", "gx", ":!open <c-r><c-a><CR>") -- open URL under cursor
-- keymap("n", "<C-u>", "<C-u>zz", { desc = "Move up one page, then vertically center buffer" })
-- keymap("n", "<C-d>", "<C-d>zz", { desc = "Move down one page, then vertically center buffer" })

vim.keymap.set("v", "<", "<gv") -- outdent visual block
vim.keymap.set("v", ">", ">gv") -- indent visual block

-- Split window management
-- keymap("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
-- keymap("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
-- keymap("n", "<leader>se", "<C-w>=", { desc = "Make splits equal" })
-- keymap("n", "<leader>sx", ":close<CR>", { desc = "Close current split" })
-- keymap("n", "<leader>sj", "<C-w>-") -- make split window height shorter
-- keymap("n", "<leader>sk", "<C-w>+") -- make split windows height taller
-- keymap("n", "<leader>sl", "<C-w>>5") -- make split windows width bigger
-- keymap("n", "<leader>sh", "<C-w><5") -- make split windows width smaller

-- Tab management
-- keymap("n", "<leader>to", ":tabnew<CR>") -- open a new tab
-- keymap("n", "<leader>tx", ":tabclose<CR>") -- close a tab
-- keymap("n", "<leader>tn", ":tabn<CR>") -- next tab
-- keymap("n", "<leader>tp", ":tabp<CR>") -- previous tab

-- Diff keymaps
-- keymap("n", "<leader>cc", ":diffput<CR>") -- put diff from current to other during diff
-- keymap("n", "<leader>cj", ":diffget 1<CR>") -- get diff from left (local) during merge
-- keymap("n", "<leader>ck", ":diffget 3<CR>") -- get diff from right (remote) during merge
-- keymap("n", "<leader>cn", "]c") -- next diff hunk
-- keymap("n", "<leader>cp", "[c") -- previous diff hunk

-- Quickfix keymaps
-- keymap("n", "<leader>qo", ":copen<CR>") -- open quickfix list
-- keymap("n", "<leader>qf", ":cfirst<CR>") -- jump to first quickfix list item
-- keymap("n", "<leader>qn", ":cnext<CR>") -- jump to next quickfix list item
-- keymap("n", "<leader>qp", ":cprev<CR>") -- jump to prev quickfix list item
-- keymap("n", "<leader>ql", ":clast<CR>") -- jump to last quickfix list item
-- keymap("n", "<leader>qc", ":cclose<CR>") -- close quickfix list

-- Vim REST Console
-- keymap("n", "<leader>xr", ":call VrcQuery()<CR>") -- Run REST query
--
-- LSP
-- keymap("n", "<leader>gg", "<cmd>lua vim.lsp.buf.hover()<CR>")
-- keymap("n", "<leader>gd", "<cmd>lua vim.lsp.buf.definition()<CR>")
-- keymap("n", "<leader>gD", "<cmd>lua vim.lsp.buf.declaration()<CR>")
-- keymap("n", "<leader>gi", "<cmd>lua vim.lsp.buf.implementation()<CR>")
-- keymap("n", "<leader>gt", "<cmd>lua vim.lsp.buf.type_definition()<CR>")
-- keymap("n", "<leader>gr", "<cmd>lua vim.lsp.buf.references()<CR>")
-- keymap("n", "<leader>gs", "<cmd>lua vim.lsp.buf.signature_help()<CR>")
-- keymap("n", "<leader>rr", "<cmd>lua vim.lsp.buf.rename()<CR>")
-- keymap("n", "<leader>gf", "<cmd>lua vim.lsp.buf.format({async = true})<CR>")
-- keymap("v", "<leader>gf", "<cmd>lua vim.lsp.buf.format({async = true})<CR>")
-- keymap("n", "<leader>ga", "<cmd>lua vim.lsp.buf.code_action()<CR>")
-- keymap("n", "<leader>gl", "<cmd>lua vim.diagnostic.open_float()<CR>")
-- keymap("n", "<leader>gp", "<cmd>lua vim.diagnostic.goto_prev()<CR>")
-- keymap("n", "<leader>gn", "<cmd>lua vim.diagnostic.goto_next()<CR>")
-- keymap("n", "<leader>tr", "<cmd>lua vim.lsp.buf.document_symbol()<CR>")
-- keymap("i", "<C-Space>", "<cmd>lua vim.lsp.buf.completion()<CR>")

-- Debugging
-- keymap("n", "<leader>bb", "<cmd>lua require'dap'.toggle_breakpoint()<cr>")
-- keymap("n", "<leader>bc", "<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<cr>")
-- keymap("n", "<leader>bl", "<cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<cr>")
-- keymap("n", "<leader>br", "<cmd>lua require'dap'.clear_breakpoints()<cr>")
-- keymap("n", "<leader>ba", "<cmd>Telescope dap list_breakpoints<cr>")
-- keymap("n", "<leader>dc", "<cmd>lua require'dap'.continue()<cr>")
-- keymap("n", "<leader>dj", "<cmd>lua require'dap'.step_over()<cr>")
-- keymap("n", "<leader>dk", "<cmd>lua require'dap'.step_into()<cr>")
-- keymap("n", "<leader>do", "<cmd>lua require'dap'.step_out()<cr>")
-- keymap("n", "<leader>dd", function()
-- 	require("dap").disconnect()
-- 	require("dapui").close()
-- end)
-- keymap("n", "<leader>dt", function()
-- 	require("dap").terminate()
-- 	require("dapui").close()
-- end)
-- keymap("n", "<leader>dr", "<cmd>lua require'dap'.repl.toggle()<cr>")
-- keymap("n", "<leader>dl", "<cmd>lua require'dap'.run_last()<cr>")
-- keymap("n", "<leader>di", function()
-- 	require("dap.ui.widgets").hover()
-- end)
-- keymap("n", "<leader>d?", function()
-- 	local widgets = require("dap.ui.widgets")
-- 	widgets.centered_float(widgets.scopes)
-- end)
-- keymap("n", "<leader>df", "<cmd>Telescope dap frames<cr>")
-- keymap("n", "<leader>dh", "<cmd>Telescope dap commands<cr>")
