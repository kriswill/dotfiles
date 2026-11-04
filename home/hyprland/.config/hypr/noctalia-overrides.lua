-- Overrides applied AFTER the desktop shell's generated colour fragment (see
-- hyprland.lua load order): Dux Shell's dms/colors.lua today, Noctalia's
-- noctalia.lua before 2026-11-03. The filename is historical; it is kept so the
-- stow link and hyprland.lua's require don't have to move in lockstep.
--
-- The shell's theme sets inactive_border to a "surface"/outline colour (Noctalia's was
-- rgb 131313; Dux uses its outline tone) that is lighter than ghostty's window bg
-- (#0e0e0e) and shows a faint line between tiled ghostty windows in gapless layouts. We
-- want the inactive border to render the same as ghostty's interior so it disappears.
-- Active border is left to the shell. (look-and-feel.lua sets inactive_border too but
-- loses to the shell fragment, which loads later — this file wins by loading last.)
--
-- ponytail: the value is tuned to the current HDR session, not ghostty's literal bg.
-- The opaque border goes through an HDR/gamma lift that ghostty content doesn't, so a
-- #0e0e0e source renders ~rgb22 (visibly lighter) while #050505 renders ~rgb13 — a near
-- match to ghostty's interior. The lift is flat (backdrop-independent, verified across
-- dark+bright wallpaper rows via grim), so a darker source doesn't make a dark line.
-- If HDR is ever disabled, re-measure: border vs interior pixels with grim, aim equal.
-- (measured 2026-06-20: source rgb14->render22, rgb19->render26  =>  ~0.8*src+11)
local surface = "rgb(050505)"

hl.config({
  general = { col = { inactive_border = surface } },
  group = {
    col = {
      border_inactive = surface,
      border_locked_inactive = surface,
    },
    groupbar = { col = { inactive = surface, locked_inactive = surface } },
  },
})
