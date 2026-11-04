---
type: Decision
title: Re-sync Graphical-Session Variables in zsh, Not in herdr
description: 'herdr panes inherit the environment of hc''s lingering core, which can predate the compositor, so they ran without WAYLAND_DISPLAY and Claude Code''s image paste failed. zsh now mirrors the session variables from the systemd user manager before each command when they look stale.'
tags: [zsh, herdr, wayland, nebula]
generated: { by: claude-code/opus-5.5, at: 2026-11-04T12:40:00-08:00 }
---

**Status:** active. **Where:**
[home/zsh/.config/zsh/session-env.zsh](../../home/zsh/.config/zsh/session-env.zsh),
[zsh module](../modules/zsh.md), [Herdr on nebula](../modules/nebula-herdr.md).

## Context

After the 2026-11-03 reboot into Dux Shell, Ctrl+V of a screenshot into
Claude Code (running in a herdr pane) pasted nothing. Dux was not at fault:
the clipboard held `image/png` (plus the file's path as `text/plain` and a
`text/uri-list`). Claude Code reads images by shelling out to
`wl-paste -l | grep image/…` and then `wl-paste --type image/png`, and the
pane had no `WAYLAND_DISPLAY`. So wl-paste aimed at a nonexistent
`wayland-0`, found nothing and printed no visible error.

The pane's environment comes from hc's core, `hc-hold-*.service`, a
transient `systemd-run --user` unit. It took the user manager's environment
at spawn and keeps it. Linger starts k's user manager at boot. That boot's
journal shows `herdr-core serve` and `hold` starting at 17:45:45, and uwsm
launching Hyprland at 17:45:51, so the core never had the session variables.
The same holder also outlives logouts and Hyprland restarts. Even a core that
started after uwsm's import would go stale, because it would keep the old
`HYPRLAND_INSTANCE_SIGNATURE` (and the old socket name, if that changes).

## Decision

A zsh `preexec` hook (`session-env.zsh`, Linux-only, skipped over SSH)
checks whether `$WAYLAND_DISPLAY` names a live socket and whether any
`$HYPRLAND_INSTANCE_SIGNATURE` names a running instance. If either check
fails, it unsets `WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
XDG_SESSION_TYPE XDG_CURRENT_DESKTOP` and re-exports whichever of them
`systemctl --user show-environment` holds. uwsm keeps that environment
current for the running session: it imports the variables at start and
unsets them at stop. This works like tmux's `update-environment`, but it
runs per command rather than per attach.

## Alternatives rejected

- **Patch hc's core to forward the client's environment.** The fix would
  live in upstream Rust that our fork would have to carry. A holder-wide
  environment would still freeze per holder.
- **Make the core wait for `graphical-session.target`.** hc spawns it on
  demand, and the README says a declared unit would compete with that. It
  would also only fix the first session after boot.
- **Restart the holder.** This kills every pane, and the next session
  would go stale the same way.
- **A `wl-paste` wrapper on PATH.** It fixes one tool and leaves `wl-copy`,
  `hyprctl` and anything else that needs the session broken.

## Consequences

- New commands in any pane get the live session's variables. A program
  already running keeps what it started with: restart it (for Claude Code,
  `/exit`, then `claude --continue`).
- Shells started inside the session (Ghostty from Hyprland) only pay for a
  `stat` or two. When the variables are stale or there is no session, each
  command costs one `systemctl` fork (about 2 ms).
- SSH shells are left alone so they never take over the desk's clipboard.
