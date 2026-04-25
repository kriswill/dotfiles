-- efm-langserver: umbrella LSP that runs CLI linters AND formatters.
-- Tool modules come from the creativenull/efmls-configs-nvim plugin,
-- which must be on runtimepath before this file is evaluated.
--
-- Format-on-save is wired in lua/config/lsp.lua via a BufWritePre
-- autocmd that filters to { name = "efm" } — only efm formats, other
-- LSPs (vtsls, rust-analyzer, gopls, lua-ls) do not.

-- Linters
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

-- biome for js/ts. Narrow rootMarkers to actual biome config files so
-- a project with only a package.json (no biome.json) isn't treated as
-- biome-managed. Without a root, biome falls back to efm's CWD.
local biome = vim.tbl_extend("force", require("efmls-configs.formatters.biome"), {
  rootMarkers = { "biome.json", "biome.jsonc", "rome.json" },
})

-- shfmt respects .editorconfig; tell efm to anchor workspace root on
-- it so shfmt picks up project-specific shell indent rules.
local shfmt = vim.tbl_extend("force", require("efmls-configs.formatters.shfmt"), {
  rootMarkers = { ".editorconfig" },
})

-- efmls-configs doesn't ship yamlfmt or xmllint modules. Define inline.
-- yamlfmt reads .yamlfmt from the project root (CWD walk-up).
local yamlfmt = {
  formatCommand = "yamlfmt -",
  formatStdin = true,
  rootMarkers = { ".yamlfmt", ".yamlfmt.yaml", ".yamlfmt.yml" },
}
local xmllint = {
  formatCommand = "xmllint --format -",
  formatStdin = true,
}

-- rumdl handles both markdown lint and format via stdin.
local rumdl_lint = {
  lintCommand = "rumdl check --stdin --stdin-filename ${INPUT} --color never",
  lintStdin = true,
  lintFormats = { "%f:%l:%c: %m" },
  lintIgnoreExitCode = true,
  rootMarkers = { "rumdl.toml", ".rumdl.toml" },
}
local rumdl_fmt = {
  formatCommand = "rumdl fmt --stdin --stdin-filename ${INPUT} --color never --silent",
  formatStdin = true,
  rootMarkers = { "rumdl.toml", ".rumdl.toml" },
}

-- Language mappings. Order within each list matters: python runs
-- isort then black; shell runs shellcheck lint + shfmt format; etc.
local languages = {
  -- Lint + format
  markdown = { rumdl_lint, rumdl_fmt },
  sh = { shellcheck, shfmt },
  bash = { shellcheck, shfmt },
  zsh = { shellcheck, shfmt },
  yaml = { yamllint, yamlfmt },
  -- Lint only
  dockerfile = { hadolint },
  gitcommit = { gitlint },
  -- Format only
  html = { prettier_d },
  javascript = { biome },
  javascriptreact = { biome },
  typescript = { biome },
  typescriptreact = { biome },
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
