-- Seamless <C-h/j/k/l> navigation across nvim splits and the surrounding
-- terminal multiplexer: move between nvim windows, and once we're against the
-- edge of the window layout, hand the motion off to the multiplexer so it
-- moves pane focus instead.
--
-- Replaces alexghergh/nvim-tmux-navigation (tmux-only) — same behaviour, plus
-- a herdr backend and no plugin dependency.
--
-- Backends are detected from the environment at startup: tmux ($TMUX) or herdr
-- ($HERDR_PANE_ID). With neither, the keys are plain window motions. Set
-- vim.g.multiplexer = "tmux" | "herdr" | "none" before this module loads to
-- override detection (useful when they're nested); an unrecognised value warns
-- once and falls back to detection, so :MultiplexerStatus never names a backend
-- that isn't wired.
--
-- The chord is mapped in normal, insert and terminal mode, because the
-- multiplexer forwards it to us whatever mode we're in and it has to keep
-- meaning "move focus" in all three. Insert-mode maps are only installed when a
-- backend is present; with no multiplexer nothing forwards the chord and vim's
-- own <C-h>/<C-j>/<C-k> keep their insert-mode meanings.
--
-- The other half of the handshake lives outside nvim: the multiplexer has to
-- forward the chord to a pane that is running vim rather than acting on it —
--   tmux:  home/tmux/.config/tmux/tmux.conf      (is_vim + if-shell send-keys)
--   herdr: home/herdr/.config/herdr/config.toml  ([[keys.command]] → herdr-nav)

local M = {}

-- Don't leave a zoomed/fullscreen pane just because nvim ran out of windows.
-- This gates the four DIRECTIONAL keys only: running out of windows is an
-- implicit reason to leave, and escaping the zoom is a surprise. <C-\> and
-- <C-Space> are explicit "go elsewhere" commands and deliberately do escape a
-- zoomed pane — gating them would make both dead keys in a zoomed single-window
-- nvim.
local disable_when_zoomed = true

-- Run a command and return stdout, or nil if it failed / took too long.
local function run(cmd)
  local ok, res = pcall(function() return vim.system(cmd, { text = true }):wait(1000) end)
  if not ok or res.code ~= 0 then
    return nil
  end
  return res.stdout or ""
end

-- Run a command for its effect. Focus changes are run synchronously and their
-- exit status is believed: "did the multiplexer actually move?" is the whole
-- input to the last-active bookkeeping below, and fire-and-forget cannot answer
-- it. (`zoomed()` already put a synchronous call in this path.)
local function run_ok(cmd) return run(cmd) ~= nil end

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
    return run_ok(tmux_cmd({ "select-pane", "-t", ":.+" }))
  end
  local flag = tmux_flags[dir]
  if not flag then
    return false
  end
  -- `select-pane -l` exits 1 with "no last pane" in a single-pane window, which
  -- is exactly when <C-\> should fall back to :wincmd p instead.
  return run_ok(tmux_cmd({ "select-pane", flag }))
end

-- herdr ---------------------------------------------------------------------

local herdr = {}

local herdr_dirs = { h = "left", j = "down", k = "up", l = "right" }

-- $HERDR_PANE_ID is read for detection only, never as a pane argument: herdr
-- pane ids are workspace-scoped, so moving this pane to another workspace or
-- tab re-ids it while nvim keeps the id it inherited at startup. `--current` is
-- resolved by the server for `pane focus`, `pane layout` and `pane
-- process-info`, and the pane we're typing in is the focused one by definition.
-- (`pane current --current` is env-first rather than server-resolved — it is
-- not a safe substitute.)
function herdr.zoomed()
  local out = run({ "herdr", "pane", "layout", "--current" })
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
  return run_ok({ "herdr", "pane", "focus", "--direction", d, "--current" })
end

-- Detection -----------------------------------------------------------------

local backends = { tmux = tmux, herdr = herdr }

local function detect()
  local forced = vim.g.multiplexer
  if forced ~= nil then
    if forced == "none" then
      return nil
    end
    if type(forced) == "string" and backends[forced] then
      return forced
    end
    vim.notify(
      ('multiplexer: ignoring unknown vim.g.multiplexer = %s (want "tmux", "herdr" or "none")'):format(
        vim.inspect(forced)
      ),
      vim.log.levels.WARN
    )
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

-- Windows taking part in this tab page's split layout. Floating windows are
-- excluded deliberately: winnr("$") counts them and :wincmd w walks into them,
-- so an open LSP-progress or notification float otherwise reads as "another
-- window to move to".
local function layout_wins()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      wins[#wins + 1] = win
    end
  end
  table.sort(wins, function(a, b) return vim.fn.win_id2win(a) < vim.fn.win_id2win(b) end)
  return wins
end

-- :wincmd is invalid in the command-line window (E11). Say so and stop: a
-- failed move leaves winnr() untouched, which would otherwise read as "at the
-- edge of the layout" and hand the pane away with the cmdwin still open.
local function in_cmdwin()
  if vim.fn.win_gettype() ~= "command" then
    return false
  end
  vim.notify("E11: Invalid in command-line window; <CR> executes, CTRL-C quits", vim.log.levels.ERROR)
  return true
end

local function to_normal_mode()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes([[<C-\><C-n>]], true, false, true), "nx", false)
end

-- Whether the multiplexer owns the "last active" pane — i.e. whether focus last
-- came from a pane rather than from another nvim window, which is what decides
-- if <C-\> delegates last-active or runs :wincmd p. True on startup so that
-- entering a fresh nvim and hitting <C-\> hands back to the pane we came from.
local mux_has_focus = true

-- Ask the multiplexer to move focus. `gate_on_zoom` applies disable_when_zoomed
-- (see above). Returns whether focus actually left nvim.
local function hand_off(dir, gate_on_zoom)
  if not backend then
    return false
  end
  if gate_on_zoom and disable_when_zoomed and backend.zoomed() then
    return false
  end
  return backend.focus(dir)
end

--- Move one step in `dir`: "h"/"j"/"k"/"l" directional, "p" last active,
--- "n" next. Stays in nvim while there are windows to move to.
function M.navigate(dir)
  if in_cmdwin() then
    return
  end

  if dir == "p" then
    if mux_has_focus and hand_off("p", false) then
      mux_has_focus = true
    else
      pcall(vim.cmd, "wincmd p")
      mux_has_focus = false
    end
    return
  end

  if dir == "n" then
    -- Leave nvim only from its last window, and reset to the first so the
    -- cycle picks up there when focus comes back.
    local wins = layout_wins()
    local current = vim.api.nvim_get_current_win()
    local index
    for i, win in ipairs(wins) do
      if win == current then
        index = i
      end
    end
    if (index == #wins or #wins <= 1) and hand_off("n", false) then
      mux_has_focus = true
      if wins[1] then
        pcall(vim.api.nvim_set_current_win, wins[1])
      end
    else
      local next_win = wins[(index or 0) % math.max(#wins, 1) + 1]
      if next_win then
        pcall(vim.api.nvim_set_current_win, next_win)
      end
      mux_has_focus = false
    end
    return
  end

  -- winnr(dir) answers "is there a window that way?" without moving, so a
  -- refused move can't be mistaken for an edge, and floats aren't counted.
  local target = vim.fn.winnr(dir)
  if target ~= vim.fn.winnr() then
    pcall(vim.cmd, target .. "wincmd w")
    mux_has_focus = false
    return
  end
  if hand_off(dir, true) then
    mux_has_focus = true
  end
  -- A refused hand-off moved focus nowhere, so whatever mux_has_focus already
  -- said is still the truth.
end

--- Same motion from insert mode: leave insert first so the chord can never be
--- taken as <BS>/<NL>/digraph input, then navigate normally.
function M.navigate_insert(dir)
  to_normal_mode()
  M.navigate(dir)
end

--- Same motion from a terminal buffer. Moving to another nvim window leaves
--- terminal mode (there is nowhere else for the keys to go); handing off to the
--- multiplexer does not — the pane just loses focus and comes back still in
--- terminal mode. With nothing in that direction and no hand-off available this
--- does nothing at all, rather than dropping the user into normal mode as a
--- side effect of a key that didn't move anything.
function M.navigate_terminal(dir)
  if in_cmdwin() then
    return
  end
  local target = vim.fn.winnr(dir)
  if target ~= vim.fn.winnr() then
    to_normal_mode()
    pcall(vim.cmd, target .. "wincmd w")
    mux_has_focus = false
    return
  end
  if hand_off(dir, true) then
    mux_has_focus = true
  end
end

-- Focus changes made outside these maps — tmux's own prefix+o, a mouse click,
-- herdr's sidebar — are otherwise invisible to the bookkeeping above, leaving
-- <C-\> pointed at an nvim window when the user actually came from a pane.
-- tmux.conf sets `focus-events on` for exactly this.
-- Caveat: FocusGained also fires when the terminal application itself regains
-- focus (alt-tab), which we can't tell apart from a pane switch, so one <C-\>
-- after alt-tabbing back may delegate where :wincmd p was meant.
if backend then
  vim.api.nvim_create_autocmd("FocusGained", {
    desc = "Focus returned from outside nvim — under a multiplexer that means a pane",
    callback = function() mux_has_focus = true end,
  })
end

-- Keymaps -------------------------------------------------------------------

local directional = {
  { "<C-h>", "h", "left" },
  { "<C-j>", "j", "down" },
  { "<C-k>", "k", "up" },
  { "<C-l>", "l", "right" },
}

local keys = vim.list_extend(vim.deepcopy(directional), {
  { "<C-\\>", "p", "to last active" },
  -- Reachability: both multiplexers are configured with ctrl+space as their
  -- prefix (tmux.conf, herdr's config.toml), so <C-Space> only reaches nvim in
  -- a bare terminal or after rebinding that prefix. Kept correct regardless.
  { "<C-Space>", "n", "to next" },
})

local where = M.name and (M.name .. " pane") or "no multiplexer"

for _, key in ipairs(keys) do
  local lhs, dir, label = key[1], key[2], key[3]
  vim.keymap.set("n", lhs, function() M.navigate(dir) end, {
    silent = true,
    desc = "Move " .. label .. " (window or " .. where .. ")",
  })
end

for _, key in ipairs(directional) do
  local lhs, dir, label = key[1], key[2], key[3]
  -- Insert mode only under a multiplexer: it forwards the chord to us whatever
  -- mode we're in, and without these maps <C-h> deletes a character, <C-j>
  -- inserts a line break and <C-k> starts a digraph instead of moving focus.
  if backend then
    vim.keymap.set("i", lhs, function() M.navigate_insert(dir) end, {
      silent = true,
      desc = "Move " .. label .. " (window or " .. where .. ") from insert",
    })
  end
  vim.keymap.set("t", lhs, function() M.navigate_terminal(dir) end, {
    silent = true,
    desc = "Move " .. label .. " (window or " .. where .. ") from terminal",
  })
end

vim.keymap.set("t", "<M-Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

vim.api.nvim_create_user_command(
  "MultiplexerStatus",
  function() vim.notify("multiplexer: " .. (M.name or "none detected")) end,
  { desc = "Show which terminal multiplexer navigation is wired to" }
)

return M
