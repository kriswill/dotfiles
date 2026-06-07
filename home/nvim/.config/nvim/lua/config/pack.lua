-- Thin wrapper around vim.pack for dispatching plugin specs to load
-- triggers. Plugin files under lua/plugins/ return specs of the form:
--   { src, name?, version?, trigger = "now"|"later"|{ft|cmd|keys=...},
--     deps = { ... }, setup = function() end }
-- See lua/config/plugins.lua for the dispatcher.

local M = {}

local function pack_name(src, override)
  if override then return override end
  return src:gsub("%.git$", ""):match("([^/]+)$")
end

local function collect(spec)
  local list = {}
  for _, dep in ipairs(spec.deps or {}) do
    table.insert(list, {
      src = dep.src,
      name = pack_name(dep.src, dep.name),
      version = dep.version,
    })
  end
  table.insert(list, {
    src = spec.src,
    name = pack_name(spec.src, spec.name),
    version = spec.version,
  })
  return list
end

local function safe_setup(spec)
  if type(spec.setup) == "function" then
    local ok, err = pcall(spec.setup)
    if not ok then
      vim.schedule(function()
        vim.notify("pack: setup failed for " .. pack_name(spec.src, spec.name) .. ": " .. tostring(err), vim.log.levels.ERROR)
      end)
    end
  end
end

function M.now(spec)
  vim.pack.add(collect(spec))
  safe_setup(spec)
end

function M.later(spec)
  vim.pack.add(collect(spec))
  if vim.v.vim_did_enter == 1 then
    vim.schedule(function() safe_setup(spec) end)
  else
    vim.api.nvim_create_autocmd("UIEnter", {
      once = true,
      callback = function() safe_setup(spec) end,
    })
  end
end

local function packadd_all(specs)
  for _, s in ipairs(specs) do
    pcall(vim.cmd.packadd, s.name)
  end
end

function M.on_ft(spec, filetypes)
  local specs = collect(spec)
  vim.pack.add(specs, { load = false })
  local fts = type(filetypes) == "string" and { filetypes } or filetypes
  local loaded = false
  local function load_once()
    if loaded then return end
    loaded = true
    packadd_all(specs)
    safe_setup(spec)
  end
  vim.api.nvim_create_autocmd("FileType", {
    pattern = fts,
    callback = load_once,
  })
  -- If a buffer of the target filetype is already open (e.g. opened via
  -- command line), the FileType event has already fired — trigger now.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.bo[buf].filetype
      for _, want in ipairs(fts) do
        if ft == want then
          load_once()
          return
        end
      end
    end
  end
end

function M.on_cmd(spec, cmds)
  local specs = collect(spec)
  vim.pack.add(specs, { load = false })
  local names = type(cmds) == "string" and { cmds } or cmds
  local loaded = false
  for _, cmd in ipairs(names) do
    vim.api.nvim_create_user_command(cmd, function(opts)
      if not loaded then
        loaded = true
        for _, n in ipairs(names) do pcall(vim.api.nvim_del_user_command, n) end
        packadd_all(specs)
        safe_setup(spec)
      end
      local args = opts.args ~= "" and (" " .. opts.args) or ""
      local bang = opts.bang and "!" or ""
      vim.cmd(("%s%s%s"):format(cmd, bang, args))
    end, { nargs = "*", bang = true })
  end
end

function M.on_keys(spec, keys)
  local specs = collect(spec)
  vim.pack.add(specs, { load = false })
  local list = keys
  if type(keys) == "string" then list = { { keys, mode = "n" } } end
  local loaded = false
  local function load_once(lhs, mode)
    if loaded then return end
    loaded = true
    for _, k in ipairs(list) do
      local m = k.mode or "n"
      local modes = type(m) == "table" and m or { m }
      for _, mm in ipairs(modes) do
        pcall(vim.keymap.del, mm, k[1] or k.lhs)
      end
    end
    packadd_all(specs)
    safe_setup(spec)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), "m", false)
  end
  for _, k in ipairs(list) do
    local lhs = k[1] or k.lhs
    local m = k.mode or "n"
    local modes = type(m) == "table" and m or { m }
    for _, mm in ipairs(modes) do
      vim.keymap.set(mm, lhs, function() load_once(lhs, mm) end, { desc = k.desc })
    end
  end
end

function M.dispatch(spec)
  local t = spec.trigger or "now"
  if t == "now" then
    M.now(spec)
  elseif t == "later" then
    M.later(spec)
  elseif type(t) == "table" then
    if t.ft then
      M.on_ft(spec, t.ft)
    elseif t.cmd then
      M.on_cmd(spec, t.cmd)
    elseif t.keys then
      M.on_keys(spec, t.keys)
    else
      error("pack: unknown trigger table for " .. pack_name(spec.src, spec.name))
    end
  else
    error("pack: invalid trigger for " .. pack_name(spec.src, spec.name))
  end
end

return M
