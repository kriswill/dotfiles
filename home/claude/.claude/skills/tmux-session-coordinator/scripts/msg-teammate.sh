#!/usr/bin/env bash
# msg-teammate.sh <tmux-window> "<message>"
#
# Reliable coordinator->teammate delivery. tmux paste rendering can swallow a
# trailing Enter sent in the same send-keys call, leaving the message stranded
# in the input box; this script sends text and Enter separately, then verifies
# from the pane that the message left the input box (a turn started or the text
# rendered into the transcript), retrying Enter a few times before giving up.
#
# An empty message performs a verified bare-Enter (submits a stranded queued
# prompt in the window's input box).
#
# Exit codes: 0 delivered/submitted, 1 could not confirm, 2 usage/window error.
set -u

if [ "${1:-}" = "--self-test" ]; then
  # Smoke test against a scratch tmux session running `cat` (echoes input).
  s="msgteammate-selftest-$$"
  tmux new-session -d -s "$s" -n target 'cat' || { echo "self-test: cannot create tmux session"; exit 1; }
  "$0" "$s:target" "hello-self-test-42"; rc=$?
  sleep 1
  if tmux capture-pane -t "$s:target" -p | grep -q "hello-self-test-42"; then
    echo "self-test: OK (rc=$rc)"; tmux kill-session -t "$s"; exit 0
  else
    echo "self-test: FAIL - text not found in pane"; tmux kill-session -t "$s"; exit 1
  fi
fi

win="${1:?usage: msg-teammate.sh <tmux-window> \"<message>\" }"
msg="${2:-}"

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

echo "delivery unconfirmed to $win - inspect the pane; consider the inbox file channel" >&2
exit 1
