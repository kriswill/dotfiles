--- @type vim.lsp.Config
return {
  cmd = { "bash-language-server", "start" },
  filetypes = {
    "sh",
    "bash",
    "zsh",
  },
  root_markers = { ".zshrc" },
  ignoredRootPaths = { "~" },
  single_file_support = true,
  settings = {
    -- Disable bashls' built-in shellcheck; efm-langserver handles it
    -- so the same SC#### diagnostic doesn't show up twice.
    bashIde = {
      shellcheckPath = "",
    },
  },
}
