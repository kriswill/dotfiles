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

vim.lsp.handlers["window/showMessage"] = function(_, result, ctx)
  if result.type == vim.lsp.protocol.MessageType.Info then
    return -- ignore info messages
  end
  vim.notify(result.message, vim.log.levels[result.type] or vim.log.levels.INFO)
end

vim.lsp.enable({
  "buf_ls",
  "nil_ls",
  "gopls",
  "luals",
  "rust_analyzer",
  "ts_ls",
  "terraform",
  "yaml",
})

-- vim.api.nvim_create_autocmd("LspAttach", {
--   group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
--   callback = function(event)
--     print "LspAttach"
--   end
-- })
