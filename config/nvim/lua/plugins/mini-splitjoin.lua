return {
  src = "https://github.com/echasnovski/mini.splitjoin",
  trigger = "now",
  setup = function()
    local sj = require("mini.splitjoin")
    sj.setup({
      mappings = { toggle = "" },
    })
    vim.keymap.set({ "n", "x" }, "sj", function() sj.join() end, { desc = "Join args" })
    vim.keymap.set({ "n", "x" }, "sk", function() sj.split() end, { desc = "Split args" })
  end,
}
