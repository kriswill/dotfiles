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
#
# Preflight (refuses before spawning; override with --force among the extra
# args): a brief still containing unexpanded template placeholders (<name>,
# <scratch>, <skill-dir>, ... — a guaranteed-wrong brief fact costs the
# teammate its first work block); a brief that does not declare the mission
# INTEGRATION POLICY ("Integration policy: <no-github|local-merge|push-only|
# prs-user-merge|prs-auto-merge>", decided with the user at Step 1 — a live
# mission opened PRs and merged despite a user instruction not to, so no
# teammate spawns without knowing the rule); or a workdir that is a PRIMARY
# git checkout rather than a linked worktree (teammates never touch the main
# checkout).
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
  # Preflight guards - both cases must refuse BEFORE any spawn attempt.
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  mkdir "$tmp/wt" "$tmp/main-co"
  printf 'Deliver X. Status file: <scratch>/status-impl.md\n' > "$tmp/brief-bad.md"
  printf 'Deliver X. No policy declared here.\n' > "$tmp/brief-nopol.md"
  printf 'Deliver X. All placeholders expanded.\nIntegration policy: push-only\n' > "$tmp/brief-ok.md"
  "$0" t "$tmp/wt" "$tmp/brief-bad.md" >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] || { echo "self-test: FAIL placeholder lint did not refuse (rc=$rc)"; exit 1; }
  "$0" t "$tmp/wt" "$tmp/brief-nopol.md" >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] || { echo "self-test: FAIL integration-policy gate did not refuse (rc=$rc)"; exit 1; }
  git -C "$tmp/main-co" init -q
  "$0" t "$tmp/main-co" "$tmp/brief-ok.md" >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] || { echo "self-test: FAIL primary-checkout guard did not refuse (rc=$rc)"; exit 1; }
  echo "self-test: OK ($mux; deps present; preflight guards refuse; spawn not exercised)"; exit 0
fi

name="${1:?usage: spawn-teammate.sh <name> <workdir> <brief-file> [claude args...]}"
workdir="${2:?missing workdir}"
brief="${3:?missing brief file}"
shift 3
extra_args=("$@")

force=0
pruned=()
for a in "${extra_args[@]:-}"; do
  [ -n "$a" ] || continue
  if [ "$a" = "--force" ]; then force=1; else pruned+=("$a"); fi
done
extra_args=(${pruned[@]+"${pruned[@]}"})

[ -d "$workdir" ] || { echo "workdir does not exist: $workdir"; exit 2; }
[ -r "$brief" ]  || { echo "brief not readable: $brief"; exit 2; }

# --- Preflight (before any mux action; --force overrides) ---
placeholders="$(grep -nE '<(name|scratch|skill-dir|branch|prefix|worktree path|\.\.\.)>|<(one-paragraph|tmux window|list the actual)' "$brief" || true)"
if [ -n "$placeholders" ] && [ "$force" = 0 ]; then
  echo "brief contains unexpanded template placeholders - a guaranteed-wrong brief fact costs the teammate its first work block:" >&2
  printf '%s\n' "$placeholders" >&2
  echo "fix the brief, or pass --force to spawn anyway" >&2
  exit 2
fi
if ! grep -qE '^Integration policy: (no-github|local-merge|push-only|prs-user-merge|prs-auto-merge)[[:space:]]*$' "$brief" \
   && [ "$force" = 0 ]; then
  echo "brief declares no integration policy - add 'Integration policy: <no-github|local-merge|push-only|prs-user-merge|prs-auto-merge>' (decided with the user at Step 1; a mission once opened PRs and merged against a user instruction); pass --force to spawn anyway" >&2
  exit 2
fi
if git -C "$workdir" rev-parse --git-dir >/dev/null 2>&1; then
  gd="$(git -C "$workdir" rev-parse --git-dir)"
  gcd="$(git -C "$workdir" rev-parse --git-common-dir)"
  if [ "$gd" = "$gcd" ] && [ "$force" = 0 ]; then
    echo "workdir $workdir is a PRIMARY git checkout, not a linked worktree - teammates get their own (git worktree add ../wt/$name -b <branch>); pass --force to spawn anyway" >&2
    exit 2
  fi
  wbranch="$(git -C "$workdir" branch --show-current 2>/dev/null || true)"
  case "$wbranch" in
    main|master) echo "WARNING: workdir is on branch '$wbranch' - teammates normally work on a feature branch" >&2 ;;
  esac
fi

[ "$mux" = none ] && { echo "not inside tmux or herdr - nothing to spawn into"; exit 2; }

model_args=(--model claude-opus-5 --effort high)
# If the caller supplied their own --model, drop the defaults.
for a in "${extra_args[@]:-}"; do [ "$a" = "--model" ] && model_args=(); done

if [ "$mux" = herdr ]; then
  command -v herdr >/dev/null || { echo "inside herdr but herdr CLI not on PATH"; exit 2; }
  # Pin the tab to the COORDINATOR's workspace (HERDR_PANE_ID = "<ws>:p<n>").
  # Without --workspace, tab create lands in the currently-FOCUSED workspace —
  # which may be a different one — and herdr has no tab-move to recover
  # (2026-07-28 mission: two teammates stranded in a sibling workspace).
  ws="${HERDR_PANE_ID%%:*}"
  # herdr agent start spawns from the SERVER's env, not the caller's: a
  # coordinator running with a custom CLAUDE_CONFIG_DIR must forward it or the
  # teammate lands in an unauthenticated default config (OAuth login screen).
  # herdr >=proto17: env forwarding moved to `tab create --env`; `agent start`
  # attaches to the tab's existing pane via --kind/--pane (pane must be at an
  # interactive shell prompt — freshly created tabs are).
  env_args=()
  [ -n "${CLAUDE_CONFIG_DIR:-}" ] && env_args=(--env "CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR")
  tab_id="$(herdr tab create --workspace "$ws" --label "$name" --cwd "$workdir" --no-focus \
    ${env_args[@]:+"${env_args[@]}"} \
    | grep -o '"tab_id":"[^"]*"' | head -1 | cut -d'"' -f4)"
  [ -n "$tab_id" ] || { echo "herdr tab create failed"; exit 2; }
  # tab get doesn't list panes; pane list carries the tab_id mapping. jq, not
  # grep: the nested scroll object separates pane_id from tab_id in the text.
  command -v jq >/dev/null || { echo "herdr spawn path needs jq on PATH"; exit 2; }
  pane_id="$(herdr pane list --workspace "$ws" \
    | jq -r --arg t "$tab_id" '.result.panes[] | select(.tab_id==$t) | .pane_id' | head -1)"
  [ -n "$pane_id" ] || { echo "no pane found in tab $tab_id"; exit 2; }
  # herdr >=proto17 shell-encodes agent args into the pane and REFUSES
  # multi-line text ("cannot be encoded safely"), so the brief can no longer
  # travel as an argv element — pass a one-line bootstrap pointing at the file.
  herdr agent start "$name" --kind claude --pane "$pane_id" -- \
    --dangerously-skip-permissions ${model_args[@]:+"${model_args[@]}"} \
    ${extra_args[@]:+"${extra_args[@]}"} \
    "Read the file $brief and follow it: it is your complete mission brief and operating instructions. Start now." \
    >/dev/null || exit 2
  # working = processing the brief; a very short first turn can finish before
  # the wait polls, so also accept visible claude chrome (as the tmux path does).
  if herdr agent wait "$name" --until working --timeout 60000 >/dev/null 2>&1 \
     || herdr agent read "$name" --source visible --lines 50 2>/dev/null \
        | grep -qE '\([0-9]+m? ?[0-9]*s? ?·|bypass permissions'; then
    echo "spawned $name (herdr tab $tab_id, cwd $workdir)"
    exit 0
  fi
  echo "WARNING: $name started but no claude activity detected - inspect the tab" >&2
  exit 1
fi

# Pin the window to the COORDINATOR's session (resolved from this pane), never
# whatever session happens to be active in another attached client. Address the
# window by id afterwards so a same-name window elsewhere can't be hit.
sess="$(tmux display-message -p ${TMUX_PANE:+-t "$TMUX_PANE"} '#{session_id}')"
win_id="$(tmux new-window -dP -F '#{window_id}' -t "${sess}:" -n "$name" -c "$workdir")" || exit 2
tmux send-keys -t "$win_id" "claude --dangerously-skip-permissions ${model_args[*]} ${extra_args[*]:-} \"\$(cat $(printf '%q' "$brief"))\"" Enter

# Verify the session came up and began processing the brief.
for i in $(seq 1 12); do
  sleep 5
  p="$(tmux capture-pane -t "$win_id" -p 2>/dev/null)"
  if printf '%s' "$p" | grep -qE '\([0-9]+m? ?[0-9]*s? ?·|bypass permissions'; then
    echo "spawned $name (window '$name', cwd $workdir)"
    exit 0
  fi
done

echo "WARNING: $name window created but no claude activity detected - inspect the pane" >&2
exit 1
