--- @type vim.lsp.Config
return {
  cmd = { "bash-language-server", "start" },
  filetypes = {
    "sh",
    "bash",
    "zsh",
    ".zshrc",
  },
  root_markers = { ".zshrc" },
  ignoredRootPaths = { "~" },
  single_file_support = true,
}
