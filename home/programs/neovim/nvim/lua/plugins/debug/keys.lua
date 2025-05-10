return {
  -- { "<Leader>dt", ":DapUiToggle<CR>", desc = "Debug Toggle UI" },
  { "<Leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
  { "<Leader>dc", function() require("dap").continue() end, desc = "Debug Continue" },
  { "<Leader>dr", function() require("dapui").open({ reset = true }) end, desc = "Reset Debugger" },
}
