-- snacks/config/globals.lua
return function()
  -- Setup some globals for debugging (lazy-loaded)
  _G.dd = function(...) Snacks.debug.inspect(...) end
  _G.bt = function() Snacks.debug.backtrace() end
  vim.print = _G.dd -- Override print to use snacks for `:=` command
end