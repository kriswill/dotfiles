#!/usr/bin/env bash
# heartbeat.sh [--interval S] [--no-submit] [--once] <teammate>...
#
# Persistent teammate monitor for the multiplexer this coordinator runs inside
# (herdr or tmux, auto-detected). Emits one line per CONFIRMED state change:
#
#   [17:42] heartbeat: impl IDLE (2 consecutive reads; was working)
#
# Encodes the monitoring lessons that cost real time in live missions:
#   - every non-working state (idle/queued/done/blocked/missing) must be seen
#     on 2 consecutive reads before it is reported — every single-read
#     idle/done alert across two missions was a turn-boundary race;
#   - tmux panes are classified by the SPINNER line, never the last line
#     (the last line is the input box: it always looks idle);
#   - herdr status comes from `herdr agent get <name>` (agent_status; any
#     non-working value is treated as idle-class and shown verbatim, so an
#     unexpected status like "done" reports rather than false-MISSINGs);
#   - an idle pane with text in its input box is QUEUED: a stranded
#     self-prompt. Once confirmed it is auto-submitted with msg-teammate.sh's
#     verified bare-Enter (harmless if the box turns out empty). Disable with
#     --no-submit.
#
# --once does a single undebounced read of every teammate and exits (triage).
# Default interval 120s. Exit codes: 0 (--once / self-test pass), 2 usage.
set -u

script_dir="$(cd "$(dirname "$0")" && pwd)"

detect_mux() {
  if [ -n "${HERDR_PANE_ID:-}" ]; then echo herdr
  elif [ -n "${TMUX:-}" ]; then echo tmux
  else echo none; fi
}
mux="$(detect_mux)"

now() { date +%H:%M; }
up() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

# classify: pane text on stdin -> working | queued | idle
classify() {
  local text bottom
  text="$(cat)"
  if printf '%s\n' "$text" | grep -qE '\([0-9]+m? ?[0-9]*s? ?·'; then
    echo working; return
  fi
  # Only the bottom of the pane can be the input box. Strip box borders and
  # edge whitespace so an empty prompt ("│ > │") doesn't read as queued.
  bottom="$(printf '%s\n' "$text" | grep -v '^[[:space:]]*$' | tail -n 8 \
    | sed -e 's/^[[:space:]│|]*//' -e 's/[[:space:]│|]*$//')"
  if printf '%s\n' "$bottom" | grep -q '\[Pasted text' \
     || printf '%s\n' "$bottom" | grep -qE '^>[[:space:]]+[^[:space:]]'; then
    echo queued; return
  fi
  echo idle
}

if [ "${1:-}" = "--self-test" ]; then
  fail=0
  expect() {
    local got; got="$(classify)"
    [ "$got" = "$2" ] || { echo "self-test: $1 classified $got (want $2)"; fail=1; }
  }
  expect spinner working <<'EOF'
✻ Churning… (3m 42s · ↓ 2.1k tokens · esc to interrupt)
EOF
  expect empty-input-box idle <<'EOF'
● Done. All 17 controls green.

╭──────────────────────────────────────────╮
│ >                                        │
╰──────────────────────────────────────────╯
  ? for shortcuts                Bypassing Permissions
EOF
  expect queued-text queued <<'EOF'
● Turn ended.

╭──────────────────────────────────────────╮
│ > run the t12 rig again with 3 samples   │
╰──────────────────────────────────────────╯
  ? for shortcuts
EOF
  expect stranded-paste queued <<'EOF'
╭──────────────────────────────────────────╮
│ > [Pasted text #1 +42 lines]             │
╰──────────────────────────────────────────╯
EOF
  expect shell-prompt idle <<'EOF'
$ ls
brief-impl.md  status-impl.md
$
EOF
  [ -x "$script_dir/msg-teammate.sh" ] || { echo "self-test: msg-teammate.sh missing/not executable"; fail=1; }
  case "$mux" in
    herdr) command -v herdr >/dev/null || { echo "self-test: inside herdr but herdr CLI not on PATH"; fail=1; } ;;
    tmux)  command -v tmux >/dev/null || { echo "self-test: tmux missing"; fail=1; } ;;
    none)  echo "self-test: note - not inside tmux or herdr (classifier only)" ;;
  esac
  [ "$fail" = 0 ] && echo "self-test: OK ($mux; classifier fixtures pass; live polling not exercised)"
  exit "$fail"
fi

interval=120
submit=1
once=0
while [ $# -gt 0 ]; do
  case "$1" in
    --interval) interval="${2:?--interval needs seconds}"; shift 2 ;;
    --no-submit) submit=0; shift ;;
    --once) once=1; shift ;;
    --*) echo "unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || { echo "usage: heartbeat.sh [--interval S] [--no-submit] [--once] <teammate>..." >&2; exit 2; }
[ "$mux" = none ] && { echo "not inside tmux or herdr - nothing to monitor" >&2; exit 2; }
[ "$mux" = herdr ] && { command -v herdr >/dev/null || { echo "inside herdr but herdr CLI not on PATH" >&2; exit 2; }; }

names=("$@")

# read_status <name> -> working|queued|idle|missing (or herdr's own status word)
read_status() {
  local name="$1" text hstatus c info
  if [ "$mux" = herdr ]; then
    info="$(herdr agent get "$name" 2>/dev/null)" || info=""
    hstatus="$(printf '%s' "$info" | grep -o '"agent_status":"[^"]*"' | head -1 | cut -d'"' -f4)"
    [ -n "$hstatus" ] || { echo missing; return; }
    [ "$hstatus" = working ] && { echo working; return; }
    # idle-class (idle/done/blocked/unknown): check the pane for stranded input
    text="$(herdr agent read "$name" --source visible --lines 40 2>/dev/null)"
    c="$(printf '%s\n' "$text" | classify)"
    if [ "$c" = queued ]; then echo queued; else echo "$hstatus"; fi
  else
    text="$(tmux capture-pane -t "$name" -p 2>/dev/null)" || { echo missing; return; }
    printf '%s\n' "$text" | classify
  fi
}

if [ "$once" = 1 ]; then
  for name in "${names[@]}"; do
    echo "[$(now)] heartbeat: $name $(up "$(read_status "$name")") (single read, undebounced)"
  done
  exit 0
fi

confirmed=() cand=() count=()
i=0
for name in "${names[@]}"; do confirmed[i]=unknown; cand[i]=none; count[i]=0; i=$((i+1)); done

echo "[$(now)] heartbeat: monitoring ${names[*]} every ${interval}s (auto-submit=$submit)"

while :; do
  i=0
  for name in "${names[@]}"; do
    s="$(read_status "$name")"
    if [ "$s" = working ]; then
      # working is definite (spinner visible / server-reported) - no debounce
      if [ "${confirmed[i]}" != working ]; then
        echo "[$(now)] heartbeat: $name WORKING"
        confirmed[i]=working
      fi
      cand[i]=none; count[i]=0
    elif [ "$s" = "${confirmed[i]}" ]; then
      cand[i]=none; count[i]=0
    else
      if [ "$s" = "${cand[i]}" ]; then count[i]=$((count[i]+1)); else cand[i]="$s"; count[i]=1; fi
      if [ "${count[i]}" -ge 2 ]; then
        echo "[$(now)] heartbeat: $name $(up "$s") (${count[i]} consecutive reads; was ${confirmed[i]})"
        confirmed[i]="$s"; cand[i]=none; count[i]=0
        if [ "$s" = queued ] && [ "$submit" = 1 ]; then
          if "$script_dir/msg-teammate.sh" "$name" "" >/dev/null 2>&1; then
            echo "[$(now)] heartbeat: $name AUTO-SUBMIT stranded input (verified bare-Enter)"
            confirmed[i]=unknown   # reclassify fresh next round
          else
            echo "[$(now)] heartbeat: $name AUTO-SUBMIT FAILED - inspect the pane"
          fi
        fi
      fi
    fi
    i=$((i+1))
  done
  sleep "$interval"
done
