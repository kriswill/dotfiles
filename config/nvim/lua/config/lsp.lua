vim.lsp.handlers["window/showMessage"] = function(_, result)
  if result.type == vim.lsp.protocol.MessageType.Info then
    return -- ignore info messages
  end
  vim.notify(result.message, vim.log.levels[result.type] or vim.log.levels.INFO)
end

vim.lsp.enable({
  "bash",
  "buf_ls",
  "css",
  "gopls",
  "html",
  "json",
  "luals",
  "nil_ls",
  "rust_analyzer",
  "terraform",
  "vtsls", -- vscode wrapper for typescript
  "yaml",
})
