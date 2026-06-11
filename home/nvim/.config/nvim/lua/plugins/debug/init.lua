local dapui_layout = require("plugins.debug.layout")
local keys = require("plugins.debug.keys")

return {
  src = "https://github.com/mfussenegger/nvim-dap",
  trigger = { keys = keys },
  deps = {
    { src = "https://github.com/rcarriga/nvim-dap-ui" },
    { src = "https://github.com/leoluz/nvim-dap-go" },
    { src = "https://github.com/nvim-neotest/nvim-nio" },
  },
  setup = function()
    local dap, dapui, dapgo = require("dap"), require("dapui"), require("dap-go")
    dapui.setup(dapui_layout)
    dapgo.setup()

    dap.listeners.before.attach.dapui_config = function() dapui.open() end
    dap.listeners.before.launch.dapui_config = function() dapui.open() end
    dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
    dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

    vim.fn.sign_define(
      "DapBreakpoint",
      { text = "⏺", texthl = "DapBreakpoint", linehl = "DapBreakpoint", numhl = "DapBreakpoint" }
    )

    -- Keymaps (previously lazy.nvim's `keys =`)
    for _, k in ipairs(keys) do
      local lhs = k[1]
      local rhs = k[2]
      vim.keymap.set("n", lhs, rhs, { desc = k.desc, silent = true })
    end
  end,
}
