-- snacks/keymaps/files.lua
return {
  -- Top level file pickers
  { "<leader><space>", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
  { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
  { "<leader>e", function() Snacks.explorer() end, desc = "File Explorer" },

  -- Find operations (<leader>f*)
  { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
  {
    "<leader>fc",
    function() Snacks.picker.files({ cwd = vim.fn.stdpath("config")[0] or "" }) end,
    desc = "Find Config File",
  },
  { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
  { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Find Git Files" },
  { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },
  { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent" },
}

