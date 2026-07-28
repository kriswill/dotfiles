-- Seamless <C-h/j/k/l> navigation across nvim splits and the surrounding
-- terminal multiplexer: move between nvim windows, and once we're against the
-- edge of the window layout, hand the motion off to the multiplexer so it
-- moves pane focus instead.
--
-- Replaces alexghergh/nvim-tmux-navigation (tmux-only) — same behaviour, plus
-- a herdr backend and no plugin dependency.
--
-- Backends are detected from the environment at startup: tmux ($TMUX) or herdr
-- ($HERDR_PANE_ID). With neither, the keys are plain :wincmd motions. Set
-- vim.g.multiplexer = "tmux" | "herdr" | "none" before this module loads to
-- override detection (useful when they're nested).
--
-- The other half of the handshake lives outside nvim: the multiplexer has to
-- forward the chord to a pane that is running vim rather than acting on it —
--   tmux:  home/tmux/.config/tmux/tmux.conf      (is_vim + if-shell send-keys)
--   herdr: home/herdr/.config/herdr/config.toml  ([[keys.command]] → herdr-nav)

local M = {}

-- Don't leave a zoomed/fullscreen pane just because nvim ran out of windows.
local disable_when_zoomed = true

-- Run a command and return stdout, or nil if it failed / took too long.
local function run(cmd)
  local ok, res = pcall(function() return vim.system(cmd, { text = true }):wait(1000) end)
  if not ok or res.code ~= 0 then
    return nil
  end
  return res.stdout or ""
end

-- Fire-and-forget: focus changes have no result we need to wait on.
local function detach(cmd) pcall(vim.system, cmd) end

-- tmux ----------------------------------------------------------------------

local tmux = {}

local tmux_flags = { h = "-L", j = "-D", k = "-U", l = "-R", p = "-l" }

local function tmux_cmd(args)
  -- $TMUX is "<socket>,<pid>,<session>"; talk to that server explicitly so a
  -- non-default socket still works.
  local socket = vim.split(vim.env.TMUX or "", ",")[1]
  return vim.list_extend({ "tmux", "-S", socket }, args)
end

function tmux.zoomed()
  local out = run(tmux_cmd({ "display-message", "-p", "#{window_zoomed_flag}" }))
  return out ~= nil and vim.trim(out) == "1"
end

function tmux.focus(dir)
  if dir == "n" then
    detach(tmux_cmd({ "select-pane", "-t", ":.+" }))
    return true
  end
  local flag = tmux_flags[dir]
  if not flag then
    return false
  end
  detach(tmux_cmd({ "select-pane", flag }))
  return true
end

-- herdr ---------------------------------------------------------------------

local herdr = {}

local herdr_dirs = { h = "left", j = "down", k = "up", l = "right" }

function herdr.zoomed()
  local out = run({ "herdr", "pane", "layout", "--pane", vim.env.HERDR_PANE_ID })
  if not out then
    return false
  end
  local ok, decoded = pcall(vim.json.decode, out)
  if not ok then
    return false
  end
  local layout = vim.tbl_get(decoded or {}, "result", "layout")
  return type(layout) == "table" and layout.zoomed == true
end

function herdr.focus(dir)
  -- herdr 0.7.4 has no CLI for last/next pane (only directional focus), so
  -- <C-\> and <C-Space> stay inside nvim there.
  local d = herdr_dirs[dir]
  if not d then
    return false
  end
  detach({ "herdr", "pane", "focus", "--direction", d, "--pane", vim.env.HERDR_PANE_ID })
  return true
end

-- Detection -----------------------------------------------------------------

local backends = { tmux = tmux, herdr = herdr }

local function detect()
  local forced = vim.g.multiplexer
  if forced ~= nil then
    return forced ~= "none" and forced or nil
  end
  -- tmux first: nvim in tmux in a herdr pane inherits $HERDR_PANE_ID too, and
  -- the innermost multiplexer is the one that owns the splits around us.
  if (vim.env.TMUX or "") ~= "" then
    return "tmux"
  end
  if (vim.env.HERDR_PANE_ID or "") ~= "" then
    return "herdr"
  end
  return nil
end

M.name = detect()
local backend = M.name and backends[M.name] or nil

-- Navigation ----------------------------------------------------------------

local function vim_navigate(dir)
  local cmd = dir == "n" and "wincmd w" or ("wincmd " .. dir)
  if not pcall(vim.cmd, cmd) then
    -- :wincmd is not allowed from the command-line window
    vim.notify("E11: Invalid in command-line window; <CR> executes, CTRL-C quits", vim.log.levels.ERROR)
  end
end

-- Whether the multiplexer owns the "last active" pane. True on startup so that
-- entering a fresh nvim and hitting <C-\> hands back to the pane we came from.
local mux_has_focus = true

--- Move one step in `dir`: "h"/"j"/"k"/"l" directional, "p" last active,
--- "n" next. Stays in nvim while there are windows to move to.
function M.navigate(dir)
  if not backend then
    return vim_navigate(dir)
  end

  if dir == "n" then
    -- Leave nvim only from its last window, and reset to the first so the
    -- cycle picks up there when focus comes back.
    if vim.fn.winnr() == vim.fn.winnr("$") and backend.focus("n") then
      pcall(vim.cmd, "wincmd t")
    else
      vim_navigate(dir)
    end
    return
  end

  if dir == "p" then
    if not (mux_has_focus and backend.focus("p")) then
      vim_navigate(dir)
    end
    return
  end

  local winnr = vim.fn.winnr()
  vim_navigate(dir)
  local at_edge = winnr == vim.fn.winnr()
  local hand_off = at_edge and not (disable_when_zoomed and backend.zoomed()) and backend.focus(dir)
  mux_has_focus = hand_off
end

-- Keymaps -------------------------------------------------------------------

local keys = {
  { "<C-h>", "h", "left" },
  { "<C-j>", "j", "down" },
  { "<C-k>", "k", "up" },
  { "<C-l>", "l", "right" },
  { "<C-\\>", "p", "to last active" },
  { "<C-Space>", "n", "to next" },
}

for _, key in ipairs(keys) do
  local lhs, dir, label = key[1], key[2], key[3]
  vim.keymap.set("n", lhs, function() M.navigate(dir) end, {
    silent = true,
    desc = "Move " .. label .. " (window or " .. (M.name or "no") .. " pane)",
  })
end

-- Terminal buffers: only move between nvim windows (a terminal job owns its
-- own <C-h> etc., so there is nothing to hand off to the multiplexer).
vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Move to left window from terminal" })
vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], { desc = "Move to window below from terminal" })
vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Move to window above from terminal" })
vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Move to right window from terminal" })
vim.keymap.set("t", "<M-Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

vim.api.nvim_create_user_command(
  "MultiplexerStatus",
  function() vim.notify("multiplexer: " .. (M.name or "none detected")) end,
  { desc = "Show which terminal multiplexer navigation is wired to" }
)

return M
