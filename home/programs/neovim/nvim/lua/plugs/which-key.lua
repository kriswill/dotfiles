local wk = require("which-key")
wk.setup({})
wk.add({
  { "<leader>/", "<cmd>Telescope live_grep<cr>", desc = "Live Grep" },
  { "<leader>P", '"+P', desc = "Paste from clipboard before cursor" },
  { "<leader>a", "<cmd>lua require('telescope.builtin').lsp_code_actions()<cr>", desc = "Code Actions" },
  { "<leader>b", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
  { "<leader>d", "<cmd>lua require('telescope.builtin').lsp_document_diagnostics()<cr>", desc = "LSP Diagnostics" },
  { "<leader>f", "<cmd>Telescope find_files<cr>", desc = "Find File" },
  { "<leader>g", group = "Git / VCS" },
  { "<leader>gb", "<cmd>ToggleBlameLine<cr>", desc = "Toggle BlameLine" },
  { "<leader>gc", "<cmd>Neogit commit<cr>", desc = "Commit" },
  { "<leader>gi", "<cmd>lua require('telescope').extensions.gh.issues()<cr>", desc = "Github Issues" },
  { "<leader>gp", "<cmd>lua require('telescope').extensions.gh.pull_request()<cr>", desc = "Github PRs" },
  { "<leader>gs", "<cmd>Neogit kind=split<cr>", desc = "Staging" },
  { "<leader>k", "<cmd>lua vim.lsp.buf.signature_help()<cr>", desc = "Signature Help" },
  { "<leader>l", group = "LSP" },
  { "<leader>le", "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<cr>", desc = "Show Line Diagnostics" },
  { "<leader>lf", "<cmd>lua vim.lsp.buf.formatting_sync()<cr>", desc = "Format file" },
  { "<leader>lq", "<cmd>lua vim.lsp.diagnostic.set_loclist()<cr>", desc = "Set Loclist" },
  { "<leader>p", '"+p', desc = "Paste from clipboard" },
  { "<leader>y", '"+y', desc = "Yank to clipboard" },
})
