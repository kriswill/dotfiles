---------------------
---- KEYBINDINGS ----
---------------------

local programs = require("programs")
local terminal, fileManager, menu = programs.terminal, programs.fileManager, programs.menu

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
--[[ local closeWindowBind = ]]
hl.bind(mainMod .. " + W", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(
  mainMod .. " + M",
  hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))

-- Dux Shell panels, driven over IPC (`dms ipc call <target> <fn>`; list them
-- all with `dms ipc list`). fuzzel stays on SUPER+D above; these add the
-- shell's own launcher, control centre, settings, and lock. See
-- docs/dux-shell.md. (Noctalia's equivalents, until 2026-11-03: `noctalia msg
-- panel-toggle launcher|control-center` and `noctalia msg session lock`, plus a
-- SUPER+SHIFT+W bind that re-applied per-monitor wallpapers after a DP-3
-- re-detect — a Noctalia-specific fallback bug, so it was not carried over.)
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("dms ipc call control-center toggle"))
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("dms ipc call lock lock"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen()) -- real fullscreen (mode 0)
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 1 })) -- maximize (mode 1)

-- Toggle zero gaps + square (un-rounded) corners on the CURRENT MONITOR only.
--
-- Gaps (general.gaps_in/out) and decoration.rounding are GLOBAL in Hyprland, so
-- per-monitor scoping is done with a workspace rule on the workspace currently
-- DISPLAYED on the focused monitor: its special/scratchpad workspace if one is
-- open (so scratchpads aren't missed), else its active workspace. This is all
-- native hl.* API — no hyprctl shell-out. State lives in a Lua table; it resets
-- on config reload, which also drops the runtime workspace rules, so the two
-- stay in sync. (The restore values 5/20 mirror the general block in
-- look-and-feel.lua — keep them in sync if those defaults change.)
--
-- Under Noctalia (until 2026-11-03) this also flipped Noctalia's rounded
-- screen-corner overlay in lockstep, via `tomato` on its settings.toml +
-- `noctalia msg config-reload` (see docs/noctalia.md); Dux Shell has no such
-- overlay, so the toggle is now Hyprland-only.
local gaplessWorkspaces = {} -- workspace name -> true while its gaps are zeroed

local function toggleGaps()
  local mon = hl.get_active_monitor()
  if not mon then
    return
  end
  local ws = mon.active_special_workspace or mon.active_workspace
  if not ws then
    return
  end
  local name = ws.name
  if gaplessWorkspaces[name] then
    gaplessWorkspaces[name] = nil
    hl.workspace_rule({ workspace = name, gaps_in = 5, gaps_out = 20, no_rounding = false })
  else
    gaplessWorkspaces[name] = true
    hl.workspace_rule({ workspace = name, gaps_in = 0, gaps_out = 0, no_rounding = true })
  end
end

hl.bind(mainMod .. " + G", toggleGaps)

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
  local key = i % 10 -- 10 maps to key 0
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots (mirrors the niri layout: region / window / monitor), all via
-- Dux Shell's `dms screenshot` CLI (native screencopy; saves a file AND copies
-- to the clipboard by default). It's a standalone Go command, so it works even
-- if the shell itself is down. Noctalia had no window verb, which is why
-- ALT+Print used a grim + hyprctl/jq geometry grab before 2026-11-03.
hl.bind("Print", hl.dsp.exec_cmd("dms screenshot")) -- region (interactive)
hl.bind("ALT + Print", hl.dsp.exec_cmd("dms screenshot window")) -- focused window
hl.bind("CTRL + Print", hl.dsp.exec_cmd("dms screenshot full")) -- focused monitor
hl.bind("CTRL + SHIFT + Print", hl.dsp.exec_cmd("dms screenshot all")) -- all monitors

-- Laptop multimedia keys for volume and LCD brightness
hl.bind(
  "XF86AudioRaiseVolume",
  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
  { locked = true, repeating = true }
)
hl.bind(
  "XF86AudioLowerVolume",
  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  { locked = true, repeating = true }
)
hl.bind(
  "XF86AudioMute",
  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  { locked = true, repeating = true }
)
hl.bind(
  "XF86AudioMicMute",
  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
  { locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
