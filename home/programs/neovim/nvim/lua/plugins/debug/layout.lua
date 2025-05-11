return {
  layouts = {
    {
      -- Main code stays in the default window (not managed by dapui)
      elements = {
        "console",
        "repl", -- REPL under the code
      },
      size = 10, -- Height in lines for the REPL (adjust as needed)
      position = "bottom", -- REPL appears at the bottom
    },
    {
      elements = {
        { id = "watches", size = 0.33 },
        { id = "scopes", size = 0.34 }, -- 'scopes' shows locals and more
        { id = "stacks", size = 0.33 },
      },
      size = 40, -- Width in columns for the right sidebar (adjust as needed)
      position = "right", -- Watches, Locals (Scopes), and Stack on the right
    },
  },
}
