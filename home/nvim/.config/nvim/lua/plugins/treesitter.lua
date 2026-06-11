-- nvim-treesitter `main` branch (Neovim 0.12+). The plugin explicitly
-- does not support lazy-loading, so trigger = "now".
-- Parsers to install. Includes injection-only and help parsers.
local parsers = {
  "bash", "c", "cpp", "go", "html", "javascript", "latex", "lua",
  "markdown", "markdown_inline", "nix", "scss", "svelte", "typst",
  "vim", "vimdoc", "vue",
}

-- Filetypes where we enable highlight + indent. (help uses vimdoc parser
-- auto-resolved by Neovim; markdown_inline is injection-only.)
local highlight_fts = {
  "bash", "c", "cpp", "go", "html", "javascript", "latex", "lua",
  "markdown", "nix", "scss", "svelte", "typst", "vim", "vue", "help",
}

return {
  src = "https://github.com/nvim-treesitter/nvim-treesitter",
  trigger = "now",
  setup = function()
    require("nvim-treesitter").setup({})

    -- Install missing parsers asynchronously. No-op for already-installed ones.
    require("nvim-treesitter").install(parsers)

    -- Enable highlight + indent on matching filetypes. Parsers that aren't
    -- installed yet will no-op — they light up after install finishes.
    vim.api.nvim_create_autocmd("FileType", {
      pattern = highlight_fts,
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })

    -- Run :TSUpdate after the plugin itself is installed/updated via vim.pack,
    -- so parsers stay pinned to versions that match the current plugin.
    vim.api.nvim_create_autocmd("User", {
      pattern = "PackChanged",
      callback = function(args)
        local d = args.data or {}
        local name = d.spec and d.spec.name
        if name == "nvim-treesitter" and (d.kind == "install" or d.kind == "update") then
          vim.schedule(function() pcall(vim.cmd, "TSUpdate") end)
        end
      end,
    })
  end,
}
