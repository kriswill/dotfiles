-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- Hyprland owns the monitor layout in this session — kanshi (the systemd user
-- service that drives displays under niri) is stopped on Hyprland start (see
-- AUTOSTART) because it overrides hl.monitor via wlr-output-management. Both
-- monitors are therefore described in full here, matched by stable description
-- (DP-* connector numbers aren't stable across boots). Mirrors the kanshi `home`
-- profile, except the OLED is forced to native scale 1 (see below).

-- Left: ROG PG348Q, portrait (rotated 90° CCW = transform 1), NATIVE scale 1.
-- Logical footprint when rotated: 1440 x 3440.
hl.monitor({
	output = "desc:Ancor Communications Inc ROG PG348Q #ASNtlPMnEjHd",
	mode = "3440x1440@59.973",
	transform = 1,
	scale = 1,
	position = "0x0",
})

-- Right: PG34WCDM gaming OLED (240Hz, G-Sync), NATIVE scale 1. XWayland/Proton
-- games can't handle fractional scaling and get broken in-game resolutions; at
-- scale 1 the game sees a true 3440x1440 display, Hyprland can direct-scanout the
-- fullscreen window, and VRR (misc.vrr=2) works natively — no gamescope needed.
-- 3440x1440 on a 34" panel is ~110 PPI, a normal desktop density. Positioned to
-- the right of the portrait monitor (x=1440) and vertically centred against it
-- ((3440-1440)/2 = 1000).
--
-- HDR: bitdepth 10 + cm "auto" (verified 2026-06-13, Hyprland 0.55). "auto" keeps
-- the SDR desktop in proper SDR (preset reports "wide" — 10-bit wide-gamut SDR) and
-- only flips the output to the full HDR/PQ pipeline (preset "hdr") when a client
-- presents HDR content. cm "hdr" (force whole desktop HDR) looked washed out for
-- everyday SDR content even with sdrbrightness/sdrsaturation tuning, so "auto" is
-- the right default for a mixed desktop+gaming OLED. NOTE: a client must speak the
-- wp_color_management_v1 protocol to trigger HDR — plain XWayland (how the WoW rule
-- below runs today) does NOT, so HDR games need PROTON_ENABLE_WAYLAND=1 DXVK_HDR=1
-- (native Wayland) or gamescope --hdr-enabled. See docs/hdr-hyprland-june-2026.md.
hl.monitor({
	output = "desc:ASUSTek COMPUTER INC PG34WCDM RCLMRS022510",
	mode = "3440x1440@239.984",
	scale = 1,
	position = "1440x1000",
	bitdepth = 10,
	cm = "auto",
})

---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal = "ghostty"
local fileManager = "dolphin"
local menu = "hyprlauncher"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
-- hl.on("hyprland.start", function ()
--   hl.exec_cmd(terminal)
--   hl.exec_cmd("nm-applet")
--   hl.exec_cmd("waybar & hyprpaper & firefox")
-- end)

hl.on("hyprland.start", function()
	-- kanshi is a systemd user service that manages displays under niri, but it
	-- also runs under Hyprland and overrides hl.monitor via wlr-output-management.
	-- Stop it here so the monitor config above is authoritative in this session.
	-- (Service stays enabled, so niri still gets kanshi.)
	hl.exec_cmd("systemctl --user stop kanshi.service")

	-- Desktop wallpaper via hyprpaper (Hyprland's own wallpaper daemon). Image
	-- and fill behaviour are configured in ~/.config/hypr/hyprpaper.conf, which
	-- points at the same repo-tracked wallpaper niri uses (symlinked into
	-- ~/.config/niri), so both sessions stay in sync. Replace any stale instance.
	hl.exec_cmd("pkill -x hyprpaper; hyprpaper")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Cursor: rose-pine-hyprcursor (native hyprcursor format — BreezeX cursor shape
-- recolored in the muted Rose Pine palette). Installed system-wide via
-- pkgs.rose-pine-hyprcursor in nixosConfigurations/nebula/configuration.nix.
-- Hyprland renders the compositor cursor from HYPRCURSOR_THEME across the whole
-- desktop (including over XWayland windows). The theme is hyprcursor-only and
-- ships no Xcursor variant, so XCURSOR_THEME is left for client-side-cursor apps
-- (GTK uses gtk-cursor-theme-name in ~/.config/gtk-*/settings.ini instead).
hl.env("HYPRCURSOR_THEME", "rose-pine-hyprcursor")
hl.env("HYPRCURSOR_SIZE", "48")
hl.env("XCURSOR_SIZE", "48")

-- XWayland apps can't do per-monitor fractional scaling. With force_zero_scaling
-- (below) they render 1:1 (crisp) instead of being bitmap-upscaled (blurry), but
-- then look tiny on a fractional monitor. Compensate per-app: Steam reads this and
-- scales its own UI back up to match DP-3's 1.33x. (Other X11 apps that look small
-- may need GDK_DPI_SCALE / QT_SCALE_FACTOR; don't set those globally — they'd
-- double-apply on native-Wayland apps.)
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.33")

----------------------
----- XWAYLAND -----
----------------------

-- Render X11 client buffers at scale 1 (no fractional bitmap upscale = no jaggy
-- text). See env note above re: per-app size compensation.
hl.config({ xwayland = { force_zero_scaling = true } })

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 20,

		border_size = 2,

		col = {
			active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
			inactive_border = "rgba(595959aa)",
		},

		-- Set to true to enable resizing windows by clicking and dragging on borders and gaps
		resize_on_border = false,

		-- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
		allow_tearing = false,

		layout = "dwindle",
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,

		-- Change transparency of focused and unfocused windows
		active_opacity = 1.0,
		inactive_opacity = 1.0,

		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a,
		},

		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- Default springs
hl.curve("easy", { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
	dwindle = {
		preserve_split = true, -- You probably want this
	},
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
	master = {
		new_status = "master",
	},
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
	scrolling = {
		fullscreen_on_one_column = true,
	},
})

----------------
----  MISC  ----
----------------

hl.config({
	misc = {
		force_default_wallpaper = -1, -- Set to 0 or 1 to disable the anime mascot wallpapers
		disable_hyprland_logo = false, -- If true disables the random hyprland logo / anime girl background. :(
		-- VRR for the G-Sync OLED (DP-3, ASUS PG34WCDM). 2 = fullscreen-only:
		-- the display only goes adaptive-sync while a fullscreen window (e.g. the
		-- gamescope game window) is focused, which avoids OLED brightness flicker
		-- on the near-static desktop. Pairs with gamescope's `--adaptive-sync`
		-- (in the Steam launch option) so the game's variable framerate drives the
		-- panel's refresh end-to-end — the fix for nested-gamescope judder.
		vrr = 2,
	},
})

---------------
---- INPUT ----
---------------

hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		follow_mouse = 1,

		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

		touchpad = {
			natural_scroll = false,
		},
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + W", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(
	mainMod .. " + M",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only

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

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move = "20 monitor_h-120",
	float = true,
})

-- World of Warcraft (Battle.net under Steam/Proton) runs as a normal XWayland
-- fullscreen window now that DP-3 is at native scale 1 (see monitor config) — no
-- gamescope. float + fullscreen keeps it out of the dwindle tiling flow so it
-- gets the whole monitor at native 3440x1440; Hyprland direct-scanout + VRR
-- (misc.vrr=2) handle smoothness. Match on TITLE, not class: WoW and the
-- Battle.net launcher share class "steam_app_3862034770"; only the title
-- distinguishes them, so a class rule would wrongly grab the launcher too.
hl.window_rule({
	name = "wow-fullscreen",
	match = { title = "World of Warcraft" },

	float = true,
	fullscreen = true,
})

-- # This config is a STUB! This should never be generated.
-- # Use the default lua config from https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua

-- $terminal = ghostty
-- $fileManager = dolphin
-- $menu = hyprlauncher
--
-- bind = $mainMod, Q, exec, $terminal
-- bind = $mainMod, C, killactive,
-- bind = $mainMod, M, exec, command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit
-- bind = $mainMod, E, exec, $fileManager
-- bind = $mainMod, V, togglefloating,
-- bind = $mainMod, R, exec, $menu

