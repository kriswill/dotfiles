# ~/.config/zsh/herdr-gh.zsh — work around a herdr terminal-query ordering bug
# that corrupts the zsh line editor after every `gh` invocation. Sourced by
# .zshrc; no-op outside herdr.
#
# The bug: `gh` (charmbracelet/termenv) probes the terminal with OSC 11
# (background color) immediately followed by CSI 6n (cursor position), and uses
# the CPR reply as a sentinel — it reads until `ESC[…R`, assuming the earlier
# OSC 11 reply already arrived. herdr 0.8.2 answers out of request order:
#
#   ESC[1;1R ESC]11;rgb:1010/1010/1414 ESC\
#   ^ CPR    ^ OSC 11 reply, second
#
# so termenv stops at the `R` and leaves the OSC 11 reply in the tty input
# buffer. zsh then reads those bytes as keystrokes: the ESC opens
# execute-named-cmd and the rest is typed into it — `execute: 1010/1010/1414\`
# — swallowing whatever you type next. Reply latency is not the issue (herdr
# answers in 0.1ms); only the ordering is wrong.
#
# NO_COLOR=1 makes termenv skip the probe entirely (COLORFGBG does not), so it
# is the narrowest fix that keeps gh working. The cost is losing gh's color
# output, hence the probe below: we only pay it while herdr is actually broken.

## Last herdr version confirmed to reply out of order. Anything newer gets
## re-probed once and, if fixed, runs gh untouched.
HERDR_GH_LAST_BROKEN_VERSION=0.8.2

## Probe the live terminal: emit the same OSC 11 + CSI 6n pair gh does, drain
## every reply byte (so nothing leaks to zsh), and report whether the OSC 11
## answer arrived before the cursor report.
##   0 = ordered (safe), 1 = out of order or no OSC 11 reply, 2 = cannot probe
_herdr_query_order_ok() {
  [[ -t 0 && -t 1 ]] || return 2
  (( $+commands[stty] && $+commands[cat] )) || return 2

  local saved reply before
  saved=$(stty -g </dev/tty 2>/dev/null) || return 2
  # min 0 time 2 → each read returns after 200ms of idle, so `cat` sees EOF and
  # exits once the terminal has stopped talking.
  stty raw -echo min 0 time 2 </dev/tty 2>/dev/null || return 2
  printf '\e]11;?\e\\\e[6n' >/dev/tty
  reply=$(command cat </dev/tty)
  stty "$saved" </dev/tty 2>/dev/null

  [[ $reply == *$'\e]11;'* ]] || return 1
  before=${reply%%$'\e]11;'*}
  [[ $before == *R* ]] && return 1
  return 0
}

## Cached probe verdict, keyed by herdr version so a herdr upgrade re-probes.
##   0 = ordered, 1 = broken
_herdr_gh_verdict() {
  local version=$1
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/herdr-query-order/$version"
  if [[ -r $cache ]]; then
    [[ $(<"$cache") == ok ]]
    return
  fi
  local rc
  _herdr_query_order_ok
  rc=$?
  (( rc == 2 )) && return 1  # can't tell (no tty) — assume broken
  mkdir -p "${cache:h}" 2>/dev/null
  (( rc == 0 )) && print ok >"$cache" || print broken >"$cache"
  return $rc
}

gh() {
  # Not in herdr: nothing to work around.
  if [[ -z $HERDR_ENV ]]; then
    command gh "$@"
    return
  fi

  if [[ -z $_HERDR_GH_VERSION ]]; then
    _HERDR_GH_VERSION=$("${HERDR_BIN_PATH:-herdr}" --version 2>/dev/null | awk '{print $2}')
  fi
  local version=$_HERDR_GH_VERSION

  # Known-broken version (or version unreadable): suppress the probe outright.
  if [[ -z $version ]] || \
     [[ $version == $HERDR_GH_LAST_BROKEN_VERSION ]] || \
     [[ $(printf '%s\n%s\n' "$version" "$HERDR_GH_LAST_BROKEN_VERSION" | sort -V | tail -1) == "$HERDR_GH_LAST_BROKEN_VERSION" ]]; then
    NO_COLOR=1 command gh "$@"
    return
  fi

  # Newer than the last known-broken version — retest once per version.
  if _herdr_gh_verdict "$version"; then
    if [[ -z $_HERDR_GH_NOTICE ]]; then
      _HERDR_GH_NOTICE=1
      print -u2 "herdr $version replies to terminal queries in order — gh color output re-enabled. Bump HERDR_GH_LAST_BROKEN_VERSION in ~/.config/zsh/herdr-gh.zsh (or drop the file) to skip this check."
    fi
    command gh "$@"
  else
    if [[ -z $_HERDR_GH_NOTICE ]]; then
      _HERDR_GH_NOTICE=1
      print -u2 "herdr $version still replies to terminal queries out of order — running gh with NO_COLOR=1."
    fi
    NO_COLOR=1 command gh "$@"
  fi
}
