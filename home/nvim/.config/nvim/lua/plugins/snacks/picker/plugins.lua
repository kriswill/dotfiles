-- snacks/picker/plugins.lua
-- Custom snacks picker to inventory plugins installed via vim.pack.
-- Fuzzy-search by name or source; the preview pane shows where it comes
-- from, whether it's loaded now, its size on disk, rev, branches, tags.
local M = {}

local function human(bytes)
  if not bytes then return "?" end
  local units = { "B", "K", "M", "G", "T" }
  local n, i = bytes, 1
  while n >= 1024 and i < #units do
    n, i = n / 1024, i + 1
  end
  return i == 1 and string.format("%d%s", n, units[i]) or string.format("%.1f%s", n, units[i])
end

-- One batched `du -sb` over every plugin dir → bytes per path,
-- excluding each plugin's `.git` dir so sizes reflect the working tree.
local function dir_sizes(paths)
  local out = {}
  if vim.fn.executable("du") == 0 or #paths == 0 then return out end
  local cmd = { "du", "-sb", "--exclude=.git" }
  vim.list_extend(cmd, paths)
  local res = vim.system(cmd, { text = true }):wait()
  for line in (res.stdout or ""):gmatch("[^\n]+") do
    local b, p = line:match("^(%d+)%s+(.*)$")
    if b and p then out[p] = tonumber(b) end
  end
  return out
end

-- vim.pack's `active` only means "added via vim.pack.add() this session" — it's
-- true even for lazy plugins registered with `load = false` (they get `:packadd!`,
-- which adds to runtimepath without sourcing). So it can't tell loaded from
-- merely-registered. Instead detect what's *actually* been brought into the
-- session: a sourced `plugin/`/`ftdetect/` script under the dir, OR a Lua
-- entry-module from the plugin present in `package.loaded` (catches plugins
-- loaded purely via `require` in a setup, e.g. oil, lualine, mini.*).
local function is_loaded(path)
  for _, s in ipairs(vim.fn.getscriptinfo()) do
    if s.name:sub(1, #path) == path then return true end
  end
  local fs = vim.uv.fs_scandir(path .. "/lua")
  while fs do
    local name, typ = vim.uv.fs_scandir_next(fs)
    if not name then break end
    local mod = typ == "directory" and name or (name:sub(-4) == ".lua" and name:sub(1, -5))
    if mod and mod ~= "init" then
      if package.loaded[mod] ~= nil then return true end
      for k in pairs(package.loaded) do -- namespaced child, e.g. mini -> mini.icons
        if k:sub(1, #mod + 1) == mod .. "." then return true end
      end
    end
  end
  return false
end

function M.find()
  local plugins = vim.pack.get()
  local paths = vim.tbl_map(function(p) return p.path end, plugins)
  local szmap = dir_sizes(paths)

  local items = {}
  for _, p in ipairs(plugins) do
    local name, src = p.spec.name, p.spec.src or ""
    items[#items + 1] = {
      text = name .. " " .. src, -- fuzzy-match target
      name = name,
      src = src,
      path = p.path,
      file = p.path, -- lets builtin file actions operate on the dir
      loaded = is_loaded(p.path),
      rev = p.rev,
      branches = p.branches or {},
      tags = p.tags or {},
      version = p.spec.version,
      bytes = szmap[p.path],
    }
  end
  table.sort(items, function(a, b) return a.name:lower() < b.name:lower() end)
  return items
end

function M.format(item)
  local a = Snacks.picker.util.align
  local ret = {}
  ret[#ret + 1] = item.loaded and { a("●", 2), "SnacksPickerGitStatusAdded" }
    or { a("○", 2), "SnacksPickerDimmed" }
  ret[#ret + 1] = { item.name, "SnacksPickerLabel" }
  return ret
end

function M.preview(ctx)
  local item = ctx.item
  local p = ctx.preview
  local buf, ns = p.win.buf, p:ns()

  -- { label, value, value-highlight }
  local rows = {
    { "Plugin", item.name, "SnacksPickerLabel" },
    { "Loaded", item.loaded and "yes" or "no (lazy / not triggered)", item.loaded and "DiagnosticOk" or "SnacksPickerDimmed" },
    { "Source", item.src, "SnacksPickerLink" },
    { "Path", item.path, "SnacksPickerDir" },
    { "Size", human(item.bytes), "Number" },
    { "Rev", item.rev or "?", "Comment" },
  }
  if item.version then
    rows[#rows + 1] = { "Version", tostring(item.version), "Number" }
  end
  if #item.branches > 0 then
    rows[#rows + 1] = { "Branches", table.concat(item.branches, ", "), "String" }
  end
  if #item.tags > 0 then
    rows[#rows + 1] = { "Tags", table.concat(item.tags, ", "), "String" }
  end

  local labelw = 9 -- widest label ("Branches") + a space
  local lines, hls = {}, {}
  for i, r in ipairs(rows) do
    local label, value = r[1], r[2]
    local indent, gap = 2, labelw - #label
    lines[i] = string.rep(" ", indent) .. label .. string.rep(" ", gap) .. value
    hls[#hls + 1] = { i - 1, indent, indent + #label, "SnacksPickerBold" }
    local vstart = indent + labelw
    hls[#hls + 1] = { i - 1, vstart, vstart + #value, r[3] }
  end

  p:set_title(item.name)
  p:set_lines(lines)
  p:wo({ number = false, relativenumber = false, signcolumn = "no" })
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, h[1], h[2], { end_col = h[3], hl_group = h[4] })
  end
end

function M.open()
  return Snacks.picker.pick({
    source = "plugins",
    finder = M.find,
    format = M.format,
    preview = M.preview,
    confirm = function(picker, item)
      picker:close()
      require("oil").open(item.path) -- browse the plugin's files
    end,
    actions = {
      open_repo = function(_, item)
        if item.src ~= "" then
          vim.ui.open(item.src)
          Snacks.notify.info("Opened " .. item.name .. " in web browser")
        end
      end,
      yank_path = function(_, item)
        vim.fn.setreg("+", item.path)
        Snacks.notify("Copied: " .. item.path)
      end,
    },
    win = {
      input = {
        keys = {
          ["<a-b>"] = { "open_repo", mode = { "n", "i" }, desc = "Open repo URL in browser" },
          ["<c-y>"] = { "yank_path", mode = { "n", "i" }, desc = "Yank path" },
        },
      },
    },
  })
end

return M
