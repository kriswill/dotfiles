return {
  src = "https://github.com/nvim-treesitter/nvim-treesitter",
  trigger = "now",
  setup = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "bash",
        "c",
        "cpp",
        "go",
        "html",
        "javascript",
        "latex",
        "lua",
        "markdown",
        "nix",
        "scss",
        "svelte",
        "typst",
        "vim",
        "vimdoc",
        "vue",
      },
      auto_install = true,
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<Enter>",
          node_incremental = "<Enter>",
          node_decremental = "<Backspace>",
          scope_incremental = false,
        },
      },
    })

    -- Run :TSUpdate after install/update (replaces lazy.nvim's build hook).
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
