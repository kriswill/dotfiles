# ~/.config/zsh/devenv-gh.zsh — work around terminal-query reply misordering
# that corrupts the zsh line editor after every `gh` invocation. Sourced by
# .zshrc. Works in any terminal; the known trigger is `devenv shell`.
#
# The bug: `gh` (charmbracelet/termenv) probes the terminal with OSC 11
# (background color) immediately followed by CSI 6n (cursor position), and uses
# the CPR reply as a sentinel — it reads until `ESC[…R`, assuming the earlier
# OSC 11 reply already arrived. If the replies come back out of order:
#
#   ESC[1;1R ESC]11;rgb:1010/1010/1414 ESC\
#   ^ CPR    ^ OSC 11 reply, second
#
# termenv stops at the `R` and leaves the OSC 11 reply in the tty input
# buffer. zsh then reads those bytes as keystrokes: the ESC opens
# execute-named-cmd and the rest is typed into it — `execute: 1010/1010/1414\`
# — swallowing whatever you type next.
#
# Cause: `devenv shell` (seen with devenv 2.2.2) runs the inner shell on a
# second pty and relays between the two. The relay answers CSI 6n from its own
# state and forwards the real OSC 11 reply afterwards, so the order flips. The
# terminal itself (Ghostty, with or without herdr) replies in order — verified
# 2026-09-03 in a plain Ghostty window: clean outside devenv, flipped inside.
# Any other pty relay (tmux, ssh, script) could misbehave the same way, which
# is why this probes the live terminal instead of checking for devenv.
#
# NO_COLOR=1 makes termenv skip the probe entirely (COLORFGBG does not), so it
# is the narrowest fix that keeps gh working. The cost is losing gh's color
# output, so we only pay it when this shell's terminal actually misorders.

## Probe the live terminal: emit the same OSC 11 + CSI 6n pair gh does, drain
## every reply byte (so nothing leaks to zsh), and report whether the OSC 11
## answer arrived before the cursor report.
##   0 = ordered (safe), 1 = out of order or no OSC 11 reply, 2 = cannot probe
_devenv_gh_query_order_ok() {
  [[ -t 0 && -t 1 ]] || return 2
  (( $+commands[stty] && $+commands[cat] )) || return 2

  local saved reply before
  saved=$(stty -g </dev/tty 2>/dev/null) || return 2
  # min 0 time 3 → each read returns after 300ms of idle, so `cat` sees EOF and
  # exits once the terminal (and any relay in front of it) has stopped talking.
  stty raw -echo min 0 time 3 </dev/tty 2>/dev/null || return 2
  printf '\e]11;?\e\\\e[6n' >/dev/tty
  reply=$(command cat </dev/tty)
  stty "$saved" </dev/tty 2>/dev/null

  [[ $reply == *$'\e]11;'* ]] || return 1
  before=${reply%%$'\e]11;'*}
  [[ $before == *R* ]] && return 1
  return 0
}

gh() {
  # Verdict for this shell session: ok | broken. Cached in a shell variable,
  # not on disk, so every new shell (including one under a pty relay) probes
  # once. A call whose stdin/stdout is not the terminal (gh ... | jq) cannot
  # probe; it runs with NO_COLOR=1 for that call only and leaves the cache
  # empty.
  local verdict=$_DEVENV_GH_VERDICT
  if [[ -z $verdict ]]; then
    local rc
    _devenv_gh_query_order_ok; rc=$?
    case $rc in
      0) verdict=ok;     _DEVENV_GH_VERDICT=$verdict ;;
      1) verdict=broken; _DEVENV_GH_VERDICT=$verdict
         print -u2 "devenv-gh: terminal replies to OSC 11 / CSI 6n out of order in this shell${DEVENV_ROOT:+ (under devenv)} — running gh with NO_COLOR=1." ;;
      *) verdict=broken ;;   # could not probe this call; do not cache
    esac
  fi

  if [[ $verdict == ok ]]; then
    command gh "$@"
  else
    NO_COLOR=1 command gh "$@"
  fi
}
