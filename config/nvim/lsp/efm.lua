-- efm-langserver: umbrella LSP that runs CLI linters AND formatters.
-- Tool modules come from the creativenull/efmls-configs-nvim plugin,
-- which must be on runtimepath before this file is evaluated.
--
-- Format-on-save is wired in lua/config/lsp.lua via a BufWritePre
-- autocmd that filters to { name = "efm" } — only efm formats, other
-- LSPs (vtsls, rust-analyzer, gopls, lua-ls) do not.

-- Linters
local markdownlint = require("efmls-configs.linters.markdownlint")
local shellcheck = require("efmls-configs.linters.shellcheck")
local hadolint = require("efmls-configs.linters.hadolint")
local gitlint = require("efmls-configs.linters.gitlint")
-- The plugin's yamllint module omits lintFormats and lintIgnoreExitCode.
-- Without the format, efm can't parse output; without ignoreExitCode,
-- efm drops warnings-only runs (yamllint returns 0 when there are no
-- errors, even if there are warnings). stdin filename is literal "stdin"
-- in yamllint's parsable output.
local yamllint = vim.tbl_extend("force", require("efmls-configs.linters.yamllint"), {
  lintFormats = {
    "stdin:%l:%c: [%trror] %m",
    "stdin:%l:%c: [%tarning] %m",
    "stdin:%l:%c: [%tnfo] %m",
  },
  lintIgnoreExitCode = true,
})

-- Formatters
local stylua = require("efmls-configs.formatters.stylua")
local prettier_d = require("efmls-configs.formatters.prettier_d")
local nixfmt = require("efmls-configs.formatters.nixfmt")
local black = require("efmls-configs.formatters.black")
local isort = require("efmls-configs.formatters.isort")
local rustfmt = require("efmls-configs.formatters.rustfmt")
local shfmt = require("efmls-configs.formatters.shfmt")

-- efmls-configs doesn't ship an xmllint module. Define it inline.
local xmllint = {
  formatCommand = "xmllint --format -",
  formatStdin = true,
}

-- Language mappings. Order within each list matters: python runs
-- isort then black; shell runs shellcheck lint + shfmt format; etc.
local languages = {
  -- Lint + format
  markdown = { markdownlint, prettier_d },
  sh = { shellcheck, shfmt },
  bash = { shellcheck, shfmt },
  zsh = { shellcheck, shfmt },
  yaml = { yamllint, prettier_d },
  -- Lint only
  dockerfile = { hadolint },
  gitcommit = { gitlint },
  -- Format only
  html = { prettier_d },
  javascript = { prettier_d },
  javascriptreact = { prettier_d },
  typescript = { prettier_d },
  typescriptreact = { prettier_d },
  lua = { stylua },
  nix = { nixfmt },
  python = { isort, black },
  rust = { rustfmt },
  xml = { xmllint },
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
    documentFormatting = true,
    documentRangeFormatting = true,
  },
}
