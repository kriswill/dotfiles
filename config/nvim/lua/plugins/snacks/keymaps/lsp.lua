-- snacks/keymaps/lsp.lua
return {
  { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition" },
  { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Goto Declaration" },
  { "<leader>sr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "LSP References Picker" },
  { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
  { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto T[y]pe Definition" },
}

