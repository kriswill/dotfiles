-- in plugins/init.lua (load *before* lspconfig)
return {
  "folke/neodev.nvim",
  opts = {}, -- default: Neovim runtime + your plugins
  priority = 60,
}
