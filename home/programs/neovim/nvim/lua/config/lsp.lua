vim.lsp.handlers["window/showMessage"] = function(_, result, ctx)
  if result.type == vim.lsp.protocol.MessageType.Info then
    return -- ignore info messages
  end
  vim.notify(result.message, vim.log.levels[result.type] or vim.log.levels.INFO)
end

vim.lsp.enable({
  "buf_ls",
  "css",
  "github",
  "gopls",
  "html",
  "json",
  "luals",
  "nil_ls",
  "rust_analyzer",
  "terraform",
  "ts_ls",
  "yaml",
})
