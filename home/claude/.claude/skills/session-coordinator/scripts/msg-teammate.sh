#!/usr/bin/env bash
# msg-teammate.sh <teammate> "<message>"
#
# Reliable coordinator->teammate delivery in whichever multiplexer we're in
# (herdr or tmux, auto-detected). <teammate> is the herdr agent name or the
# tmux window name.
#
# tmux paste rendering can swallow a trailing Enter sent in the same
# send-keys call, leaving the message stranded in the input box; both paths
# therefore send text and Enter separately, then verify the message left the
# input box (a turn started or the text rendered into the transcript),
# retrying Enter a few times before giving up.
#
# An empty message performs a verified bare-Enter (submits a stranded queued
# prompt in the teammate's input box).
#
# --inbox <scratch-dir>: belt and braces for mission-critical directives —
# BEFORE attempting delivery, append the message (time-stamped) to
# <scratch>/inbox-<teammate>.md, which every brief tells the teammate to poll
# between steps. The directive then survives even an unconfirmed send.
#
# Exit codes: 0 delivered/submitted, 1 could not confirm, 2 usage/target error.
set -u

detect_mux() {
  if [ -n "${HERDR_PANE_ID:-}" ]; then echo herdr
  elif [ -n "${TMUX:-}" ]; then echo tmux
  else echo none; fi
}
mux="$(detect_mux)"

if [ "${1:-}" = "--self-test" ]; then
  # Smoke test against a scratch pane running `cat` (echoes input); also
  # verifies --inbox mirroring lands the message in the inbox file.
  tmpi="$(mktemp -d)"; trap 'rm -rf "$tmpi"' EXIT
  inbox_ok() {
    grep -q "coordinator: hello-self-test-42" "$tmpi/inbox-$1.md" 2>/dev/null
  }
  case "$mux" in
    herdr)
      command -v herdr >/dev/null || { echo "self-test: inside herdr but herdr CLI not on PATH"; exit 1; }
      s="msgteammate-selftest-$$"
      herdr agent start "$s" --cwd /tmp --no-focus -- cat >/dev/null || { echo "self-test: cannot start herdr agent"; exit 1; }
      "$0" --inbox "$tmpi" "$s" "hello-self-test-42"; rc=$?
      sleep 1
      out="$(herdr agent read "$s" --source visible --lines 10)"
      pid="$(herdr agent get "$s" | grep -o '"pane_id":"[^"]*"' | head -1 | cut -d'"' -f4)"
      [ -n "$pid" ] && herdr pane close "$pid" >/dev/null
      inbox_ok "$s" || { echo "self-test: FAIL - message not mirrored to inbox"; exit 1; }
      if printf '%s' "$out" | grep -q "hello-self-test-42"; then
        echo "self-test: OK (herdr, rc=$rc, inbox mirrored)"; exit 0
      fi
      echo "self-test: FAIL - text not found in herdr pane"; exit 1 ;;
    tmux)
      s="msgteammate-selftest-$$"
      tmux new-session -d -s "$s" -n target 'cat' || { echo "self-test: cannot create tmux session"; exit 1; }
      "$0" --inbox "$tmpi" "$s:target" "hello-self-test-42"; rc=$?
      sleep 1
      inbox_ok "$s:target" || { echo "self-test: FAIL - message not mirrored to inbox"; tmux kill-session -t "$s"; exit 1; }
      if tmux capture-pane -t "$s:target" -p | grep -q "hello-self-test-42"; then
        echo "self-test: OK (tmux, rc=$rc, inbox mirrored)"; tmux kill-session -t "$s"; exit 0
      fi
      echo "self-test: FAIL - text not found in pane"; tmux kill-session -t "$s"; exit 1 ;;
    none) echo "self-test: not inside tmux or herdr"; exit 1 ;;
  esac
fi

inbox_dir=""
if [ "${1:-}" = "--inbox" ]; then inbox_dir="${2:?--inbox needs the scratch dir}"; shift 2; fi

win="${1:?usage: msg-teammate.sh [--inbox <scratch-dir>] <teammate> \"<message>\" }"
msg="${2:-}"

if [ -n "$inbox_dir" ] && [ -n "$msg" ]; then
  [ -d "$inbox_dir" ] || { echo "inbox dir does not exist: $inbox_dir" >&2; exit 2; }
  printf '[%s] coordinator: %s\n' "$(date +%H:%M)" "$msg" >> "$inbox_dir/inbox-$win.md" \
    || { echo "cannot append to $inbox_dir/inbox-$win.md" >&2; exit 2; }
fi

undelivered() {
  if [ -n "$inbox_dir" ]; then
    echo "delivery unconfirmed to $win - inspect the pane; directive IS in $inbox_dir/inbox-$win.md" >&2
  else
    echo "delivery unconfirmed to $win - inspect the pane; consider the inbox file channel" >&2
  fi
  exit 1
}

if [ "$mux" = herdr ]; then
  command -v herdr >/dev/null || { echo "inside herdr but herdr CLI not on PATH"; exit 2; }
  pane_id="$(herdr agent get "$win" 2>/dev/null | grep -o '"pane_id":"[^"]*"' | head -1 | cut -d'"' -f4)"
  [ -n "$pane_id" ] || { echo "no such teammate: $win"; exit 2; }
  if [ -n "$msg" ]; then
    herdr agent send "$win" "$msg" >/dev/null || exit 2
    sleep 1
  fi
  for attempt in 1 2 3 4; do
    herdr pane send-keys "$pane_id" enter >/dev/null
    [ -z "$msg" ] && exit 0   # bare-Enter: nothing stranded is success
    # Delivered if a turn started or the text rendered into the transcript.
    if herdr agent wait "$win" --status working --timeout 5000 >/dev/null 2>&1; then
      exit 0
    fi
    frag="$(printf '%s' "$msg" | head -c 40)"
    p="$(herdr agent read "$win" --source visible --lines 40 2>/dev/null)"
    if ! printf '%s' "$p" | grep -q '\[Pasted text' && printf '%s' "$p" | grep -qF "$frag"; then
      exit 0
    fi
    [ "$attempt" -lt 4 ] && sleep 2
  done
  undelivered
fi

[ "$mux" = tmux ] || { echo "not inside tmux or herdr"; exit 2; }
tmux has-session 2>/dev/null || { echo "no tmux server"; exit 2; }
tmux list-panes -t "$win" >/dev/null 2>&1 || { echo "no such window: $win"; exit 2; }

pane() { tmux capture-pane -t "$win" -p 2>/dev/null; }

if [ -n "$msg" ]; then
  tmux send-keys -t "$win" -l "$msg" || exit 2
  sleep 2
fi

for attempt in 1 2 3 4; do
  tmux send-keys -t "$win" Enter
  sleep 3
  p="$(pane)"
  # Delivered if: no unsubmitted-paste marker AND (a spinner/elapsed line is
  # visible, or our message text appears above the input separator).
  if ! printf '%s' "$p" | grep -q '\[Pasted text'; then
    if [ -z "$msg" ]; then
      exit 0   # bare-Enter: nothing stranded is success
    fi
    frag="$(printf '%s' "$msg" | head -c 40)"
    if printf '%s' "$p" | grep -qF "$frag" || printf '%s' "$p" | grep -qE '\([0-9]+m? ?[0-9]*s? ?·'; then
      exit 0
    fi
  fi
  [ "$attempt" -lt 4 ] && sleep 2
done

undelivered
