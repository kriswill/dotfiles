vim.lsp.config("*", {
  capabilities = {
    textDocument = {
      semanticTokens = {
        multilineTokenSupport = true,
      },
    },
  },
  root_markers = { ".git" },
})
vim.lsp.enable({
  "buf_ls",
  "nil_ls",
  "gopls",
  "luals",
  "rust_analyzer",
  "ts_ls",
  "terraform",
})

-- vim.api.nvim_create_autocmd("LspAttach", {
--   group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
--   callback = function(event)
--     print "LspAttach"
--   end
-- })
