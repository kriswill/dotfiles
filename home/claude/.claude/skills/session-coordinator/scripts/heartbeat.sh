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
#     --no-submit;
#   - context usage is watched too, because a teammate stopped at "Context
#     limit reached" reads as plain idle (one sat there ~21 h with auto-compact
#     off). The % comes from the pane's status line (the line naming the model,
#     e.g. "⣿⣿⡆ 97%  Opus 5.5"); "Context limit reached" counts only in the last
#     8 non-blank lines, because older copies stay on screen. Emits
#     "<name> CONTEXT NN%" at --ctx-threshold (default 80, 0 disables) and every
#     +5 above it, and "<name> CONTEXT LIMIT REACHED" once per occurrence. Act
#     with a bare `/compact`: `/compact <focus line>` failed outright at 97%.
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

# ctx_parse: pane text on stdin -> "<pct or -> <limit 0|1>"
ctx_parse() {
  local text pct limit=0
  text="$(cat)"
  pct="$(printf '%s\n' "$text" | grep -E 'Opus|Sonnet|Haiku|Fable' | grep -oE '[0-9]{1,3}%' | tail -n 1 | tr -d %)"
  printf '%s\n' "$text" | grep -v '^[[:space:]]*$' | tail -n 8 | grep -q 'Context limit reached' && limit=1
  echo "${pct:--} $limit"
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
  expect_ctx() {
    local got; got="$(ctx_parse)"
    [ "$got" = "$2" ] || { echo "self-test: ctx $1 parsed '$got' (want '$2')"; fail=1; }
  }
  expect_ctx at-limit "97 1" <<'EOF'
  ⎿  Context limit reached · /compact or /clear to continue · auto-compact is off
✻ Crunched for 0s · done 1:20 PM · 1 shell still running
──────────────────────────────────────────────────────────────
❯
──────────────────────────────────────────────────────────────
  p4harness main ⣿⣿⡆ 97%  Opus 5.5 (xhigh)    WORK  ·
  ⏵⏵ bypass permissions on · 1 shell · ← for agents
EOF
  expect_ctx stale-limit-scrolled-up "5 0" <<'EOF'
  ⎿  Context limit reached · /compact or /clear to continue
⏺ Compacted. Resuming.
  Ran 1 shell command
⏺ Checking tracked runs
  ⎿  $ git status --short
     M bin/drive-case.sh
✶ Puzzling… (15s · ↓ 1.5k tokens)
──────────────────────────────────────────────────────────────
❯
──────────────────────────────────────────────────────────────
  p4harness main ⡀⣀⣀ 5%  Opus 5.5 (xhigh)    WORK  ·
  ⏵⏵ bypass permissions on (shift+tab to cycle)
EOF
  expect_ctx no-percent "- 0" <<'EOF'
❯
  p4harness main  Opus 5.5 (xhigh)    WORK  ·
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
ctx_threshold=80
while [ $# -gt 0 ]; do
  case "$1" in
    --interval) interval="${2:?--interval needs seconds}"; shift 2 ;;
    --ctx-threshold) ctx_threshold="${2:?--ctx-threshold needs a percent}"; shift 2 ;;
    --no-submit) submit=0; shift ;;
    --once) once=1; shift ;;
    --*) echo "unknown option: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || { echo "usage: heartbeat.sh [--interval S] [--no-submit] [--ctx-threshold PCT] [--once] <teammate>..." >&2; exit 2; }
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

# read_ctx <name> -> "<pct or -> <limit 0|1>" (visible pane; herdr allows it while working)
read_ctx() {
  local name="$1"
  if [ "$mux" = herdr ]; then
    herdr agent read "$name" --source visible --lines 40 2>/dev/null | ctx_parse
  else
    tmux capture-pane -t "$name" -p 2>/dev/null | ctx_parse
  fi
}

if [ "$once" = 1 ]; then
  for name in "${names[@]}"; do
    read -r pct lim <<< "$(read_ctx "$name")"
    echo "[$(now)] heartbeat: $name $(up "$(read_status "$name")") (single read, undebounced; context ${pct}%$([ "$lim" = 1 ] && echo ', LIMIT REACHED'))"
  done
  exit 0
fi

confirmed=() cand=() count=() ctx_last=() ctx_lim=()
i=0
for name in "${names[@]}"; do confirmed[i]=unknown; cand[i]=none; count[i]=0; ctx_last[i]=0; ctx_lim[i]=0; i=$((i+1)); done

echo "[$(now)] heartbeat: monitoring ${names[*]} every ${interval}s (auto-submit=$submit, context alert at ${ctx_threshold}%)"

while :; do
  i=0
  for name in "${names[@]}"; do
    if [ "$ctx_threshold" != 0 ]; then
      read -r pct lim <<< "$(read_ctx "$name")"
      if [ "$lim" = 1 ]; then
        [ "${ctx_lim[i]}" = 0 ] && echo "[$(now)] heartbeat: $name CONTEXT LIMIT REACHED - send a bare /compact"
        ctx_lim[i]=1
      else
        ctx_lim[i]=0
      fi
      if [ "$pct" != - ] && [ "$pct" -ge "$ctx_threshold" ]; then
        if [ "$pct" -ge $((ctx_last[i] + 5)) ]; then
          echo "[$(now)] heartbeat: $name CONTEXT ${pct}% - compact it while idle (bare /compact)"
          ctx_last[i]=$pct
        fi
      else
        ctx_last[i]=0
      fi
    fi
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
