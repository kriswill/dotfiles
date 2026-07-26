#!/usr/bin/env bash
# spawn-teammate.sh <name> <workdir> <brief-file> [extra claude args...]
#
# Spawns a teammate claude session in a new tmux window named <name>, cwd
# <workdir>, with the brief file's contents as the initial prompt, then
# verifies the session actually started processing. Defaults to the strongest
# model at high effort; override via extra args (passed through to claude).
#
# The brief travels as "$(cat file)" inside the shell command - never typed
# through send-keys - so paste-rendering length limits don't apply.
set -u

if [ "${1:-}" = "--self-test" ]; then
  command -v tmux >/dev/null || { echo "self-test: tmux missing"; exit 1; }
  command -v claude >/dev/null || { echo "self-test: claude missing"; exit 1; }
  echo "self-test: OK (deps present; spawn not exercised)"; exit 0
fi

name="${1:?usage: spawn-teammate.sh <name> <workdir> <brief-file> [claude args...]}"
workdir="${2:?missing workdir}"
brief="${3:?missing brief file}"
shift 3
extra_args=("$@")

[ -d "$workdir" ] || { echo "workdir does not exist: $workdir"; exit 2; }
[ -r "$brief" ]  || { echo "brief not readable: $brief"; exit 2; }

model_args=(--model claude-opus-5 --effort high)
# If the caller supplied their own --model, drop the defaults.
for a in "${extra_args[@]:-}"; do [ "$a" = "--model" ] && model_args=(); done

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
