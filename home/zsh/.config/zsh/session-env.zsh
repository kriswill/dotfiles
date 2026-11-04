# ~/.config/zsh/session-env.zsh — keep a shell's graphical-session variables
# pointed at the live session. Linux only; a no-op on macOS and over SSH.
# Sourced by .zshrc.
#
# herdr panes are children of hc's core, a transient systemd-run unit that
# lingers across logins and can start before the compositor does (linger
# starts k's user manager at boot). The core's environment is frozen when it
# spawns. On nebula's 2026-11-03 boot it started 6 s before uwsm launched
# Hyprland, so every pane lacked WAYLAND_DISPLAY. Anything that talks to the
# compositor then fails quietly. Claude Code's Ctrl+V image paste shells out
# to `wl-paste -l`, finds no image and pastes nothing. hyprctl can't find
# Hyprland, and wl-copy can't copy.
#
# uwsm keeps the systemd user manager's environment current for the running
# session: it imports these variables at start and unsets them at stop. So
# before each command, if ours look stale, mirror them from there (like
# tmux's update-environment). A program that is already running keeps the
# environment it started with, so restart it. SSH shells are skipped so they
# never grab the desk's clipboard.

[[ $OSTYPE == linux* && -z ${SSH_CONNECTION-} ]] || return 0
(( $+commands[systemctl] )) || return 0

typeset -ga _session_env_vars=(
  WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
  XDG_SESSION_TYPE XDG_CURRENT_DESKTOP
)

# Live = WAYLAND_DISPLAY names a socket that exists, and any Hyprland
# signature names a running instance. A stat or two, no fork, so shells
# started inside the session (Ghostty from Hyprland) pay nothing.
_session_env_live() {
  local rt=${XDG_RUNTIME_DIR:-/run/user/$UID} sock=${WAYLAND_DISPLAY-}
  [[ -n $sock ]] || return 1
  [[ $sock == /* ]] || sock=$rt/$sock
  [[ -S $sock ]] || return 1
  [[ -z ${HYPRLAND_INSTANCE_SIGNATURE-} || -d $rt/hypr/$HYPRLAND_INSTANCE_SIGNATURE ]]
}

_session_env_sync() {
  _session_env_live && return 0
  local line
  unset $_session_env_vars
  for line in ${(f)"$(systemctl --user show-environment 2>/dev/null)"}; do
    # Values systemd had to escape come out as $'…'. None of these need it.
    [[ ${line#*=} == \$\'* ]] && continue
    (( ${_session_env_vars[(Ie)${line%%=*}]} )) && export "$line"
  done
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _session_env_sync
_session_env_sync
