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

-- World of Warcraft (the `battlenet` launcher, GE-Proton) runs as a native
-- Wayland fullscreen window on DP-3 at native scale 1 (see monitor config), with
-- no gamescope. Under Wine's Wayland driver (PROTON_ENABLE_WAYLAND=1, since
-- 2026-10-25) the classes are "wow.exe" and "battle.net.exe". Under XWayland
-- both shared one "steam_app_…" class, which is why these rules match on TITLE.
-- float + fullscreen keeps WoW out of the dwindle tiling flow so it gets the
-- whole monitor at native 3440x1440; Hyprland direct scanout + VRR (misc.vrr=2)
-- handle smoothness. Workspace 9 lives on the right OLED (DP-3) and WoW always
-- opens there.
hl.workspace_rule({
  workspace = "9",
  monitor = "desc:ASUSTek COMPUTER INC PG34WCDM RCLMRS022510",
})

-- Reserve workspace 9 for WoW alone. Anything that OPENS on ws9 is bounced to
-- ws8; the wow-fullscreen rule below re-lands WoW on 9. Rules are last-match-
-- wins on the workspace prop (wiki: "the last match takes precedence"), so WoW
-- matches both this and its own rule and its own rule (declared after) wins,
-- while every other window matches only this one and gets parked on ws8.
-- ponytail: catches auto-opens only; a deliberate `movetoworkspace 9` still
-- works (workspace assignment is a static, open-time effect). Change "8 silent"
-- to another workspace if you'd rather park strays elsewhere.
hl.window_rule({
  name = "workspace-9-wow-only",
  match = { workspace = "9" },

  workspace = "8 silent",
})

-- suppress_event: under Wine's Wayland driver, WoW (in its exclusive fullscreen
-- mode) asks to leave fullscreen while its window isn't yet monitor-sized.
-- Hyprland obeyed, leaving a floating window with gaps and the bar showing,
-- and it took Super+F twice to recover (2026-10-25). Ignoring WoW's own
-- fullscreen requests keeps this rule's fullscreen. "maximize" repeats the
-- global suppress-maximize-events rule, which this one would otherwise replace
-- (last match wins).
hl.window_rule({
  name = "wow-fullscreen",
  match = { title = "World of Warcraft" },

  workspace = "9 silent", -- pinned to ws9 (right OLED via the workspace rule above)
  float = true,
  fullscreen = true,
  suppress_event = "fullscreen maximize",
})
