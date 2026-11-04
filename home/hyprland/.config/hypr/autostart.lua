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
  -- The desktop shell (bar, launcher, control centre, lock screen,
  -- notifications, wallpaper) is Dux Shell. It is NOT started here: its
  -- systemd user unit dms.service is WantedBy graphical-session.target, which
  -- the uwsm session reaches (modules/hosts/nebula/users/k/dux-shell.nix).
  -- Keybinds drive it with `dms ipc call …`. No separate wallpaper daemon
  -- (hyprpaper) runs: the shell paints the wallpaper.

  -- 1Password, started minimized to tray with --silent. It HAS to be running for
  -- the SSH agent at ~/.1password/agent.sock to exist — that agent serves git
  -- commit signing (op-ssh-sign), ssh, and sudo (see sudo-1password.nix). When the
  -- app is running-but-locked, those uses pop 1Password's unlock prompt on demand;
  -- when it's NOT running the socket is a dead leftover and they fail outright with
  -- "could not connect to socket". So keep it alive from session start. (Requires
  -- "Use the SSH agent" + "Integrate with 1Password CLI" enabled in its settings.)
  hl.exec_cmd("1password --silent")
end)
