-- snacks/config/toggles.lua
return function()
  -- Create some toggle mappings
  Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
  Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
  Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
  Snacks.toggle.diagnostics():map("<leader>ud")
  Snacks.toggle.line_number():map("<leader>ul")
  Snacks.toggle
    .option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
    :map("<leader>uc")
  Snacks.toggle.treesitter():map("<leader>uT")
  Snacks.toggle.inlay_hints():map("<leader>uh")
  Snacks.toggle.indent():map("<leader>ug")
  Snacks.toggle.dim():map("<leader>uD")
end