# herdr-open: open a link in the browser of the machine you're looking at the
# terminal from, whichever machine runs the program that opens it.
#
#   usage: herdr-open <url>          $BROWSER for Claude Code, gh and the rest
#          herdr-open --where <url>  say which Herdr window would open it, open nothing
#
# In an hc terminal ($HC_TERMINAL_ID), an http(s) URL becomes a label on that
# terminal: herdr-open.<ms>-<hex>=<url>. herdr-core sends label changes to
# every Herdr window that knows the terminal, on any machine, and the
# herdr-open mod in each one (home/herdr-app/.config/herdr-app/mods/herdr-open)
# decides whether the person is in front of it. One claims the request
# (<key>.claim), opens the link there and answers on <key>.done:
#
#   <client> here   opened in that window's browser: done
#   <client> host   open it on this machine instead (a loopback address seen
#                   from another machine means this one)
#   <client> dry-*  the same answers for --where, with nothing opened
#
# No answer within $HERDR_OPEN_WAIT_MS (default 2500): no Herdr window is
# showing the terminal to someone, so it opens here, as it did before this
# existed. Anything else goes straight to the usual opener: not in an hc
# terminal, another scheme, more than one argument, HERDR_OPEN=off, no hc.
#
# The usual opener is /usr/bin/open on macOS and xdg-open elsewhere, always
# with BROWSER unset: xdg-open falls back to $BROWSER, which is this.
# HERDR_OPEN_LOCAL names another one (tests use a logger).
#
# Labels can't come from terminal output, so a `cat` of a hostile file can't
# reach anyone's browser through this; only a process that can talk to a core
# can, which already runs as you. The mod repeats every check made here.

wait_ms=${HERDR_OPEN_WAIT_MS:-2500}
max_url=8192

local_open() {
  if [[ -n ${HERDR_OPEN_LOCAL:-} ]]; then
    exec "$HERDR_OPEN_LOCAL" "$@"
  fi
  if [[ $(uname -s) == Darwin ]]; then
    exec /usr/bin/open "$@"
  fi
  exec env -u BROWSER xdg-open "$@"
}

where=0
if [[ ${1:-} == --where ]]; then
  where=1
  shift
fi

if (($# != 1)); then
  if ((where)); then
    echo "usage: herdr-open [--where] <url>" >&2
    exit 2
  fi
  local_open "$@"
fi
url=$1

# Why this URL stays on this machine, or nothing when it can be forwarded.
reason=""
if [[ -z ${HC_TERMINAL_ID:-} ]]; then
  reason="not in an hc terminal"
elif [[ ${HERDR_OPEN:-} == off ]]; then
  reason="HERDR_OPEN=off"
elif ((${#url} > max_url)); then
  reason="longer than $max_url bytes"
elif ! [[ $url =~ ^[Hh][Tt][Tt][Pp][Ss]?://[^[:space:][:cntrl:]]+$ ]]; then
  reason="not an http(s) URL"
elif ! command -v hc >/dev/null 2>&1; then
  reason="no hc on PATH"
fi

if [[ -n $reason ]]; then
  if ((where)); then
    echo "here ($(uname -n)): $reason"
    exit 1
  fi
  local_open "$url"
fi

terminal=$HC_TERMINAL_ID
now_ms() { date +%s%3N; }
key="herdr-open.$(now_ms)-$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
((where)) && key+="-dry"

cleanup() {
  hc label "$terminal" "$key=" "$key.claim=" "$key.done=" >/dev/null 2>&1 || true
}

if ! hc label "$terminal" "$key=$url" >/dev/null 2>&1; then
  if ((where)); then
    echo "here ($(uname -n)): can't label terminal $terminal"
    exit 1
  fi
  local_open "$url"
fi

answer=""
deadline=$(($(now_ms) + wait_ms))
while (($(now_ms) < deadline)); do
  answer=$(hc get "$terminal" --json 2>/dev/null | jq -r --arg k "$key.done" '.labels[$k] // empty' 2>/dev/null || true)
  [[ -n $answer ]] && break
  sleep 0.05
done
cleanup

client=${answer%% *}
verdict=${answer#* }

if ((where)); then
  case $answer in
    "") echo "here ($(uname -n)): no Herdr window answered within $wait_ms ms" ;;
    *" dry-here") echo "$client: opens in that machine's browser" ;;
    *" dry-host") echo "here ($(uname -n)): $client hands it back (a loopback address there)" ;;
    *) echo "unexpected answer from $client: $verdict" ;;
  esac
  [[ -n $answer ]]
  exit
fi

[[ $verdict == here ]] && exit 0
local_open "$url"
