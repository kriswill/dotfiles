--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

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

-- Example window rules that are useful

-- local suppressMaximizeRule =
hl.window_rule({
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

-- Noctalia: blur the shell's bar/panel background surfaces so their
-- translucency reads against the wallpaper. Recommended by docs.noctalia.dev;
-- pair `ignorealpha` with Noctalia's own background-opacity settings.
hl.layer_rule({
  name = "noctalia-blur",
  match = { namespace = "noctalia-background-.*$" },
  blur = true,
  blur_popups = true,
  ignore_alpha = 0.5,
})

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
-- Workspace 9 lives on the right OLED (DP-3) and WoW always opens there.
hl.workspace_rule({
  workspace = "9",
  monitor = "desc:ASUSTek COMPUTER INC PG34WCDM RCLMRS022510",
})

hl.window_rule({
  name = "wow-fullscreen",
  match = { title = "World of Warcraft" },

  workspace = "9 silent", -- pinned to ws9 (right OLED via the workspace rule above)
  float = true,
  fullscreen = true,
})
