#!/usr/bin/env bash
# msg-teammate.sh <teammate> "<message>"
#
# Reliable coordinator->teammate delivery wherever we're running (hc or tmux,
# auto-detected: HC_TERMINAL_ID first, then TMUX). <teammate> is the hc
# terminal name (or address) or the tmux window name.
#
# hc: `hc send` pastes and submits in one call and reports whether the turn
# started (`started: true`; a message to a working teammate queues and also
# reports true). It refuses a teammate that is blocked on a dialog (exit 9);
# this script never forces past that - a person must answer the dialog.
# Delivered text arrives wrapped in <hc from="tN">...</hc>.
#
# tmux paste rendering can swallow a trailing Enter sent in the same
# send-keys call, leaving the message stranded in the input box; the tmux path
# therefore sends text and Enter separately, then verifies the message left the
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
  if [ -n "${HC_TERMINAL_ID:-}" ]; then echo hc
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
    hc)
      { command -v hc >/dev/null && command -v jq >/dev/null; } || { echo "self-test: inside hc but hc or jq not on PATH"; exit 1; }
      s="msgteammate-selftest-$$"
      hc run --bg --json --no-notify --name "$s" --cwd /tmp -- cat >/dev/null || { echo "self-test: cannot start hc terminal"; exit 1; }
      "$0" --inbox "$tmpi" "$s" "hello-self-test-42"; rc=$?
      sleep 1
      out="$(hc read "$s" --lines 10 2>/dev/null)"
      hc kill "$s" >/dev/null 2>&1; hc rm "$s" >/dev/null 2>&1
      inbox_ok "$s" || { echo "self-test: FAIL - message not mirrored to inbox"; exit 1; }
      if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "hello-self-test-42"; then
        echo "self-test: OK (hc, rc=$rc, inbox mirrored)"; exit 0
      fi
      echo "self-test: FAIL - rc=$rc or text not found in hc terminal"; exit 1 ;;
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
    none) echo "self-test: not inside hc or tmux"; exit 1 ;;
  esac
fi

inbox_dir=""
if [ "${1:-}" = "--inbox" ]; then inbox_dir="${2:?--inbox needs the scratch dir}"; shift 2; fi

win="${1:?usage: msg-teammate.sh [--inbox <scratch-dir>] <teammate> \"<message>\" }"
msg="${2:-}"

# A message that looks like a flag is almost always a misplaced option. Calling
# this as `msg-teammate.sh <name> --inbox <dir> "<text>"` binds msg to the
# literal string "--inbox", discards the real text as surplus argv, and then
# DELIVERS THE FLAG and exits 0 - which silently corrupted four consecutive
# coordinator directives in a live mission. Refuse rather than deliver garbage.
case "$msg" in
  --*)
    echo "refusing to send a message beginning with '--' (got: $msg)" >&2
    echo "  --inbox <scratch-dir> must come FIRST, before the teammate name" >&2
    exit 2 ;;
esac

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

if [ "$mux" = hc ]; then
  { command -v hc >/dev/null && command -v jq >/dev/null; } || { echo "inside hc but hc or jq not on PATH"; exit 2; }
  info="$(hc get "$win" --json 2>/dev/null)" || { echo "no such teammate: $win"; exit 2; }
  if [ -z "$msg" ]; then
    # Let hc send enforce its blocked-state and human-draft protections even
    # for an empty message. Raw keys could answer a newly opened dialog.
    state="$(printf '%s' "$info" | jq -r '.status.state // "plain"')"
    case "$state" in
      idle|done|plain) ;;
      *) echo "$win is $state; refusing automatic Enter" >&2; undelivered ;;
    esac
  fi
  out="$(hc send --json "$win" "$msg" 2>&1)"; rc=$?
  if [ "$rc" = 9 ]; then
    echo "$win is blocked on a dialog that needs a person - hc read $win; not forcing" >&2
    undelivered
  fi
  [ "$rc" = 0 ] || { echo "hc send failed (rc=$rc): $out" >&2; undelivered; }
  started="$(printf '%s' "$out" | jq -r '.started // empty' 2>/dev/null)"
  status="$(printf '%s' "$out" | jq -r '.status // empty' 2>/dev/null)"
  [ "$started" = true ] && exit 0
  if [ -n "$status" ]; then
    # hc already handles submission. An unconfirmed send needs inspection;
    # a second Enter could submit twice or answer a newly opened dialog.
    undelivered
  fi
  [ -z "$msg" ] && exit 0
  # A plain program reports no status (started: null): confirm the text
  # rendered on its screen instead.
  frag="$(printf '%s' "$msg" | head -c 40)"
  for attempt in 1 2 3; do
    hc read "$win" --lines 40 2>/dev/null | grep -qF -- "$frag" && exit 0
    [ "$attempt" -lt 3 ] && sleep 2
  done
  undelivered
fi

[ "$mux" = tmux ] || { echo "not inside hc or tmux"; exit 2; }
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
