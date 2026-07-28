#!/usr/bin/env bash
# spawn-teammate.sh <name> <workdir> <brief-file> [extra claude args...]
#
# Spawns a teammate claude session in the multiplexer this coordinator is
# running inside — a new tmux window or a new herdr tab, auto-detected from
# the environment (HERDR_PANE_ID vs TMUX) — named <name>, cwd <workdir>, with
# the brief file's contents as the initial prompt, then verifies the session
# actually started processing. Defaults to the strongest model at high
# effort; override via extra args (passed through to claude).
#
# The brief travels as an argv element / "$(cat file)" - never typed through
# send-keys - so paste-rendering length limits don't apply.
set -u

detect_mux() {
  if [ -n "${HERDR_PANE_ID:-}" ]; then echo herdr
  elif [ -n "${TMUX:-}" ]; then echo tmux
  else echo none; fi
}
mux="$(detect_mux)"

if [ "${1:-}" = "--self-test" ]; then
  command -v claude >/dev/null || { echo "self-test: claude missing"; exit 1; }
  case "$mux" in
    herdr) command -v herdr >/dev/null || { echo "self-test: inside herdr but herdr CLI not on PATH"; exit 1; } ;;
    tmux)  command -v tmux >/dev/null || { echo "self-test: tmux missing"; exit 1; } ;;
    none)  echo "self-test: not inside tmux or herdr"; exit 1 ;;
  esac
  echo "self-test: OK ($mux; deps present; spawn not exercised)"; exit 0
fi

name="${1:?usage: spawn-teammate.sh <name> <workdir> <brief-file> [claude args...]}"
workdir="${2:?missing workdir}"
brief="${3:?missing brief file}"
shift 3
extra_args=("$@")

[ -d "$workdir" ] || { echo "workdir does not exist: $workdir"; exit 2; }
[ -r "$brief" ]  || { echo "brief not readable: $brief"; exit 2; }
[ "$mux" = none ] && { echo "not inside tmux or herdr - nothing to spawn into"; exit 2; }

model_args=(--model claude-opus-5 --effort high)
# If the caller supplied their own --model, drop the defaults.
for a in "${extra_args[@]:-}"; do [ "$a" = "--model" ] && model_args=(); done

if [ "$mux" = herdr ]; then
  command -v herdr >/dev/null || { echo "inside herdr but herdr CLI not on PATH"; exit 2; }
  tab_id="$(herdr tab create --label "$name" --cwd "$workdir" --no-focus \
    | grep -o '"tab_id":"[^"]*"' | head -1 | cut -d'"' -f4)"
  [ -n "$tab_id" ] || { echo "herdr tab create failed"; exit 2; }
  herdr agent start "$name" --tab "$tab_id" --cwd "$workdir" --no-focus -- \
    claude --dangerously-skip-permissions ${model_args[@]:+"${model_args[@]}"} \
    ${extra_args[@]:+"${extra_args[@]}"} "$(cat "$brief")" >/dev/null || exit 2
  # working = processing the brief; a very short first turn can finish before
  # the wait polls, so also accept visible claude chrome (as the tmux path does).
  if herdr agent wait "$name" --status working --timeout 60000 >/dev/null 2>&1 \
     || herdr agent read "$name" --source visible --lines 50 2>/dev/null \
        | grep -qE '\([0-9]+m? ?[0-9]*s? ?·|bypass permissions'; then
    echo "spawned $name (herdr tab $tab_id, cwd $workdir)"
    exit 0
  fi
  echo "WARNING: $name started but no claude activity detected - inspect the tab" >&2
  exit 1
fi

tmux new-window -d -n "$name" -c "$workdir" || exit 2
tmux send-keys -t "$name" "claude --dangerously-skip-permissions ${model_args[*]} ${extra_args[*]:-} \"\$(cat $(printf '%q' "$brief"))\"" Enter

# Verify the session came up and began processing the brief.
for i in $(seq 1 12); do
  sleep 5
  p="$(tmux capture-pane -t "$name" -p 2>/dev/null)"
  if printf '%s' "$p" | grep -qE '\([0-9]+m? ?[0-9]*s? ?·|bypass permissions'; then
    echo "spawned $name (window '$name', cwd $workdir)"
    exit 0
  fi
done

echo "WARNING: $name window created but no claude activity detected - inspect the pane" >&2
exit 1
