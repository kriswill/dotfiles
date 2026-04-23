-- Plugin load order. Each entry is a module name under lua/plugins/
-- that returns a pack spec (or a list of pack specs).
-- Load order is significant: kanagawa first so colors are ready; snacks
-- early; treesitter before treesitter-textobjects.

local pack = require("config.pack")

local order = {
  "colorscheme",
  "snacks",
  "highlight-colors",
  "lualine",
  "oil-nvim",
  "blink-cmp",
  "treesitter",
  "treesitter-textobjects",
  "treesitter-context",
  "gitsigns",
  "schemastore",
  "fidget",
  "vim-sleuth",
  "baleia",
  "direnv",
  "tmux",
  "advanced-new-file",
  "colorful-winsep",
  "mini-splitjoin",
  "conform",
  "which-key",
  "lazydev-nvim",
  "debug",
}

local function run(spec)
  if not spec then return end
  if spec.src then
    pack.dispatch(spec)
  elseif type(spec) == "table" and spec[1] and spec[1].src then
    for _, s in ipairs(spec) do pack.dispatch(s) end
  end
end

for _, name in ipairs(order) do
  local ok, spec = pcall(require, "plugins." .. name)
  if not ok then
    vim.schedule(function()
      vim.notify("plugins: failed to load '" .. name .. "': " .. tostring(spec), vim.log.levels.ERROR)
    end)
  else
    run(spec)
  end
end
