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
  "dockerfile",
  "efm", -- umbrella for CLI linters + formatters (see lsp/efm.lua)
  "gopls",
  "html",
  "json",
  "luals",
  "nil_ls",
  "rust_analyzer",
  -- "terraform",
  "tofu_ls",
  "vtsls", -- vscode wrapper for typescript
  "yaml",
})

-- Format on save via efm. Filter ensures only efm formats; other LSPs
-- that advertise formatting capability (vtsls, rust-analyzer, gopls,
-- lua-ls, etc.) are skipped so there's a single source of formatting.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("efm-format-on-save", { clear = true }),
  callback = function(args)
    vim.lsp.buf.format({
      bufnr = args.buf,
      async = false,
      timeout_ms = 500,
      filter = function(c) return c.name == "efm" end,
    })
  end,
})
