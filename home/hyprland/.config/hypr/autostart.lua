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

  -- Desktop wallpaper is painted by the Noctalia shell (started below), so no
  -- separate wallpaper daemon (hyprpaper) runs in this session.

  -- Noctalia shell (bar, launcher, control centre, lock screen, notifications).
  -- Installed for k via modules/hosts/nebula/users/k/noctalia.nix. --daemon
  -- backgrounds the shell so this returns immediately; keybinds below drive it
  -- with `noctalia msg`. Replace any stale instance left by a session restart.
  hl.exec_cmd("pkill -x noctalia; noctalia --daemon")
end)
