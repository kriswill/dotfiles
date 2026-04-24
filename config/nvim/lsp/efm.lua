-- efm-langserver: umbrella LSP that runs CLI linters.
-- Tool modules come from the creativenull/efmls-configs-nvim plugin,
-- which must be on runtimepath before this file is evaluated.
local markdownlint = require("efmls-configs.linters.markdownlint")
local hadolint = require("efmls-configs.linters.hadolint")
local gitlint = require("efmls-configs.linters.gitlint")
local shellcheck = require("efmls-configs.linters.shellcheck")

-- The plugin's yamllint module omits lintFormats and
-- lintIgnoreExitCode. Without the format, efm can't parse output;
-- without ignoreExitCode, efm drops warnings-only runs (yamllint
-- returns 0 when there are no errors, even if there are warnings).
-- stdin filename is literal "stdin" in yamllint's parsable output.
local yamllint = vim.tbl_extend("force", require("efmls-configs.linters.yamllint"), {
  lintFormats = {
    "stdin:%l:%c: [%trror] %m",
    "stdin:%l:%c: [%tarning] %m",
    "stdin:%l:%c: [%tnfo] %m",
  },
  lintIgnoreExitCode = true,
})

-- bash-language-server's built-in shellcheck is disabled in
-- lsp/bash.lua (settings.bashIde.shellcheckPath = ""), so efm is the
-- single source of SC#### diagnostics here.
local languages = {
  markdown = { markdownlint },
  sh = { shellcheck },
  bash = { shellcheck },
  zsh = { shellcheck },
  dockerfile = { hadolint },
  yaml = { yamllint },
  gitcommit = { gitlint },
}

--- @type vim.lsp.Config
return {
  cmd = { "efm-langserver" },
  filetypes = vim.tbl_keys(languages),
  root_markers = { ".git/" },
  settings = {
    rootMarkers = { ".git/" },
    languages = languages,
  },
  init_options = {
    -- Lint-only; conform.nvim handles formatting.
    documentFormatting = false,
    documentRangeFormatting = false,
  },
}
