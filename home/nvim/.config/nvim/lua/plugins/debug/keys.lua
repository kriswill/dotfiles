return {
  { "<Leader>dt", function() require("dapui").toggle() end, desc = "Debug Toggle UI" },
  { "<Leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
  { "<Leader>dc", function() require("dap").continue() end, desc = "Debug: Continue" },
  { "<Leader>dr", function() require("dapui").open({ reset = true }) end, desc = "Reset Debugger UI" },
  { "<F5>", function() require("dap").continue() end, desc = "Debug: Continue" },
  { "<F10>", function() require("dap").step_over() end, desc = "Debug: Step Over" },
  { "<F11>", function() require("dap").step_into() end, desc = "Debug: Step In" },
  { "<F12>", function() require("dap").step_out() end, desc = "Debug: Step Out" },
  { "<M-b>", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
  { "<M-B>", function() require("dap").toggle_breakpoint() end, desc = "Toggle Conditional Breakpoint" },
  {
    "<M-B>",
    function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end,
    desc = "Set Conditional Breakpoint",
  },
}
