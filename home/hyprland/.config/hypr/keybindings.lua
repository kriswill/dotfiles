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

-- Noctalia shell panels, driven over IPC (`noctalia msg`). fuzzel stays on
-- SUPER+D above; these add Noctalia's own launcher, control centre, and
-- lock. See docs.noctalia.dev v5 IPC reference.
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("noctalia msg session lock"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen()) -- real fullscreen (mode 0)
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 1 })) -- maximize (mode 1)

-- Toggle zero gaps + square (un-rounded) corners on the CURRENT MONITOR only,
-- plus Noctalia's rounded screen-corner overlay to match (gaps off -> corners
-- off so windows go truly edge-to-edge; gaps on -> corners on).
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
-- The Noctalia side is a separate process with no Lua API, so it necessarily
-- goes through hl.exec_cmd: `tomato` flips [shell.screen_corners].enabled while
-- preserving formatting, written to a same-dir temp then atomically `mv`d in (an
-- in-place edit races Noctalia's file watcher into a destructive re-save), then
-- `noctalia msg config-reload` applies it live. See docs/noctalia.md.
local gaplessWorkspaces = {} -- workspace name -> true while its gaps are zeroed

local function setNoctaliaScreenCorners(enabled)
  hl.exec_cmd(
    [==[s="$HOME/.local/state/noctalia/settings.toml"; command -v tomato >/dev/null 2>&1 || exit 0; [ -f "$s" ] || exit 0; t=$(mktemp -p "$(dirname "$s")" .settings.toml.XXXXXX) || exit 0; if cp "$s" "$t" && tomato set shell.screen_corners.enabled ]==]
      .. tostring(enabled)
      .. [==[ "$t"; then mv -f "$t" "$s"; command -v noctalia >/dev/null 2>&1 && noctalia msg config-reload >/dev/null 2>&1; else rm -f "$t"; fi]==]
  )
end

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
    setNoctaliaScreenCorners(true)
  else
    gaplessWorkspaces[name] = true
    hl.workspace_rule({ workspace = name, gaps_in = 0, gaps_out = 0, no_rounding = true })
    setNoctaliaScreenCorners(false)
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

-- Screenshots (mirrors the niri layout: region / window / monitor)
-- region + monitor go through noctalia (native screencopy, saves + notifies);
-- window has no native verb, so grab the active window's geometry and copy it.
hl.bind("Print", hl.dsp.exec_cmd("noctalia msg screenshot-region"))
hl.bind(
  "ALT + Print",
  hl.dsp.exec_cmd(
    [[grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" - | wl-copy]]
  )
)
hl.bind("CTRL + Print", hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen"))
hl.bind("CTRL + SHIFT + Print", hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen pick"))

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
