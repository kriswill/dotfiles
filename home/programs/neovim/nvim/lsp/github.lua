---@type vim.lsp.Config
---@requires https://github.com/lttb/gh-actions-language-server
return {
  cmd = { "gh-actions-language-server", "--stdio" },
  filetypes = { "yaml.github" },
  root_markers = { ".github" },
  init_options = {
    -- require the `repo` and `workflow` scope
    sessionToken = os.getenv("GH_TOKEN"),
  },
  single_file_support = true,
  workspace_required = true,
  capabilities = {
    workspace = {
      didChangeWorkspaceFolders = {
        dynamicRegistration = true,
      },
    },
  },
}
