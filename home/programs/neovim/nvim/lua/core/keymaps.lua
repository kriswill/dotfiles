local map = vim.keymap.set
--local map = api.nvim_set_keymap

-- General keymaps
map("i", "jk", "<ESC>") -- Exit insert mode with jk
map("i", "ii", "<ESC>") -- Exit insert mode with ii
map("n", "<leader>wq", ":wq<CR>") -- save and quit
map("n", "<leader>qq", ":q!<CR>") -- quit without saving
map("n", "<leader>ww", ":w<CR>") -- save
map("n", "gx", ":!open <c-r><c-a><CR>") -- open URL under cursor

-- Split window management
map("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
map("n", "<leader>se", "<C-w>=", { desc = "Make splits equal" })
map("n", "<leader>sx", ":close<CR>", { desc = "Close current split" })
map("n", "<leader>sj", "<C-w>-")  -- make split window height shorter
map("n", "<leader>sk", "<C-w>+")  -- make split windows height taller
map("n", "<leader>sl", "<C-w>>5") -- make split windows width bigger
map("n", "<leader>sh", "<C-w><5") -- make split windows width smaller

-- Tab management
map("n", "<leader>to", ":tabnew<CR>") -- open a new tab
map("n", "<leader>tx", ":tabclose<CR>") -- close a tab
map("n", "<leader>tn", ":tabn<CR>") -- next tab
map("n", "<leader>tp", ":tabp<CR>") -- previous tab

map('n', '<tab>', '<cmd>bnext<cr>', { desc = 'next buffer' })
map('n', '<S-tab>', '<cmd>bprevious<cr>', { desc = 'previous buffer' })
map('n', '<A-h>', '<C-w>h', { noremap = true, silent = false, desc = 'move to left window' })
map('n', '<A-j>', '<C-w>j', { noremap = true, silent = false, desc = 'move to window below' })
map('n', '<A-k>', '<C-w>k', { noremap = true, silent = false, desc = 'move to window above' })
map('n', '<A-l>', '<C-w>l', { noremap = true, silent = false, desc = 'move to right window' })
map('n', '<C-/>', ':CommentToggle<CR>', { noremap = true, silent = true, desc = "Toggle comments" })
map('v', '<C-/>', ':CommentToggle<CR>', { noremap = true, silent = true, desc = "Toggle comments" })

-- Diff keymaps
map("n", "<leader>cc", ":diffput<CR>") -- put diff from current to other during diff
map("n", "<leader>cj", ":diffget 1<CR>") -- get diff from left (local) during merge
map("n", "<leader>ck", ":diffget 3<CR>") -- get diff from right (remote) during merge
map("n", "<leader>cn", "]c") -- next diff hunk
map("n", "<leader>cp", "[c") -- previous diff hunk

-- Quickfix keymaps
map("n", "<leader>qo", ":copen<CR>") -- open quickfix list
map("n", "<leader>qf", ":cfirst<CR>") -- jump to first quickfix list item
map("n", "<leader>qn", ":cnext<CR>") -- jump to next quickfix list item
map("n", "<leader>qp", ":cprev<CR>") -- jump to prev quickfix list item
map("n", "<leader>ql", ":clast<CR>") -- jump to last quickfix list item
map("n", "<leader>qc", ":cclose<CR>") -- close quickfix list

-- Vim REST Console
map("n", "<leader>xr", ":call VrcQuery()<CR>") -- Run REST query

-- LSP
map('n', '<leader>gg', '<cmd>lua vim.lsp.buf.hover()<CR>')
map('n', '<leader>gd', '<cmd>lua vim.lsp.buf.definition()<CR>')
map('n', '<leader>gD', '<cmd>lua vim.lsp.buf.declaration()<CR>')
map('n', '<leader>gi', '<cmd>lua vim.lsp.buf.implementation()<CR>')
map('n', '<leader>gt', '<cmd>lua vim.lsp.buf.type_definition()<CR>')
map('n', '<leader>gr', '<cmd>lua vim.lsp.buf.references()<CR>')
map('n', '<leader>gs', '<cmd>lua vim.lsp.buf.signature_help()<CR>')
map('n', '<leader>rr', '<cmd>lua vim.lsp.buf.rename()<CR>')
map('n', '<leader>gf', '<cmd>lua vim.lsp.buf.format({async = true})<CR>')
map('v', '<leader>gf', '<cmd>lua vim.lsp.buf.format({async = true})<CR>')
map('n', '<leader>ga', '<cmd>lua vim.lsp.buf.code_action()<CR>')
map('n', '<leader>gl', '<cmd>lua vim.diagnostic.open_float()<CR>')
map('n', '<leader>gp', '<cmd>lua vim.diagnostic.goto_prev()<CR>')
map('n', '<leader>gn', '<cmd>lua vim.diagnostic.goto_next()<CR>')
map('n', '<leader>tr', '<cmd>lua vim.lsp.buf.document_symbol()<CR>')
map('i', '<C-Space>', '<cmd>lua vim.lsp.buf.completion()<CR>')

-- Debugging
map("n", "<leader>bb", "<cmd>lua require'dap'.toggle_breakpoint()<cr>")
map("n", "<leader>bc", "<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<cr>")
map("n", "<leader>bl", "<cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<cr>")
map("n", '<leader>br', "<cmd>lua require'dap'.clear_breakpoints()<cr>")
map("n", '<leader>ba', '<cmd>Telescope dap list_breakpoints<cr>')
map("n", "<leader>dc", "<cmd>lua require'dap'.continue()<cr>")
map("n", "<leader>dj", "<cmd>lua require'dap'.step_over()<cr>")
map("n", "<leader>dk", "<cmd>lua require'dap'.step_into()<cr>")
map("n", "<leader>do", "<cmd>lua require'dap'.step_out()<cr>")
map("n", '<leader>dd', function() require('dap').disconnect(); require('dapui').close(); end)
map("n", '<leader>dt', function() require('dap').terminate(); require('dapui').close(); end)
map("n", "<leader>dr", "<cmd>lua require'dap'.repl.toggle()<cr>")
map("n", "<leader>dl", "<cmd>lua require'dap'.run_last()<cr>")
map("n", '<leader>di', function() require "dap.ui.widgets".hover() end)
map("n", '<leader>d?', function() local widgets = require "dap.ui.widgets"; widgets.centered_float(widgets.scopes) end)
map("n", '<leader>df', '<cmd>Telescope dap frames<cr>')
map("n", '<leader>dh', '<cmd>Telescope dap commands<cr>')

