return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      html = { "prettierd", "prettier" },
      javascript = { "prettierd", "prettier" },
      lua = { "stylua" },
      markdown = { "deno_fmt", "prettierd", "prettierd" },
      nix = { "nixfmt", "nixpkgs-fmt" },
      python = { "isort", "black" },
      rust = { "rustfmt" },
      typescript = { "prettierd", "prettier" },
      xml = { "xmllint", "xmlformat" },
      yaml = { "prettierd", "prettier", "yamlfmt", "yq" },
    },
    default_format_opts = {
      lsp_format = "fallback",
      stop_after_first = true,
    },
    format_on_save = {
      timeout_ms = 500,
    },
  },
}
