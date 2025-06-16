---@type vim.lsp.Config
return {
  cmd = { "nil" },
  init_options = {
    nix = {
      flake = {
        autoArchive = true,
        -- auto eval flake inputs for improved completion
        -- generates too many issues
        autoEvalInputs = false,
      },
    },
  },
  settings = {
    formatting = {
      command = { "nixfmt" },
    },
    diagnostic = {
      ignored = { "unused_binding", "unused_with" },
      excludedFiles = {},
    },
    telemetry = { enable = false },
  },
  filetypes = { "nix" },
}
