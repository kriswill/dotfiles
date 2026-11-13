#!/usr/bin/env bash
# spawn-teammate.sh <name> <workdir> <brief-file> [extra claude args...]
#
# Spawns a teammate claude session where this coordinator is running — a new
# hc (herdr-core) terminal or a new tmux window, auto-detected from the
# environment (HC_TERMINAL_ID first, then TMUX) — named <name>, cwd <workdir>,
# with the brief file's contents as the initial prompt, then verifies the
# session actually started processing. Defaults to the strongest model at high
# effort; override via extra args (passed through to claude).
#
# The brief travels as an argv element / "$(cat file)" - never typed through
# send-keys - so paste-rendering length limits don't apply.
#
# hc: the teammate is a child terminal of the coordinator's, started with
# --outlive-parent so a coordinator restart does not take the team down (tmux
# windows survived that too). hc starts programs with the LOGIN session's
# environment, not the caller's, so CLAUDE_CONFIG_DIR is forwarded explicitly
# through `env` - without it the teammate opens an unauthenticated default
# config. hc names are 1-32 of a-z 0-9 - _, unique among live terminals.
#
# Preflight (refuses before spawning; override with --force among the extra
# args): a brief still containing unexpanded template placeholders (<name>,
# <scratch>, <skill-dir>, ... — a guaranteed-wrong brief fact costs the
# teammate its first work block); a brief that does not declare the mission
# INTEGRATION POLICY ("Integration policy: <no-github|no-submit|local-merge|push-only|
# prs-user-merge|prs-auto-merge>", decided with the user at Step 1 — a live
# mission opened PRs and merged despite a user instruction not to, so no
# teammate spawns without knowing the rule); or a workdir that is a PRIMARY
# git checkout rather than a linked worktree (teammates never touch the main
# checkout).
set -u

detect_mux() {
  if [ -n "${HC_TERMINAL_ID:-}" ]; then echo hc
  elif [ -n "${TMUX:-}" ]; then echo tmux
  else echo none; fi
}
mux="$(detect_mux)"

if [ "${1:-}" = "--self-test" ]; then
  command -v claude >/dev/null || { echo "self-test: claude missing"; exit 1; }
  case "$mux" in
    hc)   { command -v hc >/dev/null && command -v jq >/dev/null; } || { echo "self-test: inside hc but hc or jq not on PATH"; exit 1; } ;;
    tmux) command -v tmux >/dev/null || { echo "self-test: tmux missing"; exit 1; } ;;
    none) echo "self-test: not inside hc or tmux"; exit 1 ;;
  esac
  # hc name rule: the gate must refuse before any spawn attempt.
  if [ "$mux" = hc ]; then
    tmpn="$(mktemp -d)"; mkdir "$tmpn/wt"
    printf 'Deliver X.\nIntegration policy: push-only\n' > "$tmpn/brief.md"
    # --model: p4c-style copies refuse a spawn without one before the name gate,
    # which would pass this test for the wrong reason; the message pins it.
    out="$("$0" Bad.Name "$tmpn/wt" "$tmpn/brief.md" --model sonnet 2>&1)"; rc=$?
    rm -rf "$tmpn"
    { [ "$rc" = 2 ] && printf "%s" "$out" | grep -q "hc terminal names"; } \
      || { echo "self-test: FAIL hc name gate did not refuse (rc=$rc: $out)"; exit 1; }
  fi
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

# Every brief tells the teammate to poll inbox-<name>.md "between steps", but
# that file does not exist until the coordinator's first --inbox message - so a
# standing instruction points at nothing until then (an entire mission, once).
# Create it at spawn, deriving the scratch dir from the status-file path the
# brief already mandates.
seed_inbox() {
  [ -f "$brief" ] || return 0
  sp="$(grep -o "/[^ '\"]*status-${name}.md" "$brief" 2>/dev/null | head -1)"
  [ -n "$sp" ] || return 0
  d="$(dirname "$sp")"
  [ -d "$d" ] || return 0
  : >> "$d/inbox-${name}.md" 2>/dev/null || true
}
seed_inbox
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
placeholders="$(grep -nE '<(name|scratch|skill-dir|branch|prefix|worktree path|\.\.\.)>|<(one-paragraph|tmux window|hc terminal|list the actual)' "$brief" || true)"
if [ -n "$placeholders" ] && [ "$force" = 0 ]; then
  echo "brief contains unexpanded template placeholders - a guaranteed-wrong brief fact costs the teammate its first work block:" >&2
  printf '%s\n' "$placeholders" >&2
  echo "fix the brief, or pass --force to spawn anyway" >&2
  exit 2
fi
if ! grep -qE '^Integration policy: (no-github|no-submit|local-merge|push-only|prs-user-merge|prs-auto-merge)[[:space:]]*$' "$brief" \
   && [ "$force" = 0 ]; then
  echo "brief declares no integration policy - add 'Integration policy: <no-github|no-submit|local-merge|push-only|prs-user-merge|prs-auto-merge>' (decided with the user at Step 1; a mission once opened PRs and merged against a user instruction); pass --force to spawn anyway" >&2
  exit 2
fi
# PERFORCE MODE (2026-09-18): a tree with no git at all cannot have linked worktrees; the
# primary-checkout guard is skipped and the policy no-submit (per-agent numbered changelists,
# nobody submits) carries the same meaning as no-github.
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

[ "$mux" = none ] && { echo "not inside hc or tmux - nothing to spawn into"; exit 2; }

model_args=(--model claude-opus-5 --effort high)
# If the caller supplied their own --model, drop the defaults.
for a in "${extra_args[@]:-}"; do [ "$a" = "--model" ] && model_args=(); done

if [ "$mux" = hc ]; then
  { command -v hc >/dev/null && command -v jq >/dev/null; } || { echo "inside hc but hc or jq not on PATH"; exit 2; }
  if ! printf '%s' "$name" | grep -qE '^[a-z0-9_-]{1,32}$'; then
    echo "hc terminal names are 1-32 of a-z 0-9 - _ (got: $name)"; exit 2
  fi
  env_args=(env)
  [ -n "${CLAUDE_CONFIG_DIR:-}" ] && env_args+=("CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR")
  out="$(hc run --bg --json --outlive-parent --name "$name" --cwd "$workdir" -- \
    "${env_args[@]}" claude --dangerously-skip-permissions ${model_args[@]:+"${model_args[@]}"} \
    ${extra_args[@]:+"${extra_args[@]}"} "$(cat "$brief")" 2>&1)" \
    || { echo "hc run failed: $out"; exit 2; }
  addr="$(printf '%s' "$out" | jq -r '.address // empty' 2>/dev/null)"
  [ -n "$addr" ] || { echo "hc run returned no address: $out"; exit 2; }
  # Status is claude's own OSC 7501 report (hc get .status.state), never screen
  # text. A very short first turn can already be done by the first poll, so a
  # finished turn (turn >= 1) also counts as started.
  for _ in $(seq 1 30); do
    sleep 2
    info="$(hc get "$addr" --json 2>/dev/null)" || info='{}'
    tstate="$(printf '%s' "$info" | jq -r '.state // "unknown"')"
    st="$(printf '%s' "$info" | jq -r '.status.state // "none"')"
    turn="$(printf '%s' "$info" | jq -r '.turn // 0')"
    if [ "$tstate" = finished ]; then
      echo "$name exited during startup (exit $(printf '%s' "$info" | jq -r '.exit_code')) - hc read $addr" >&2
      exit 2
    fi
    case "$st" in
      working) echo "spawned $name (hc terminal $addr, cwd $workdir)"; exit 0 ;;
      idle|done)
        if [ "$turn" -ge 1 ]; then echo "spawned $name (hc terminal $addr, cwd $workdir; first turn already ended)"; exit 0; fi ;;
      blocked) echo "WARNING: $name is blocked at startup (a dialog needs a person) - hc read $addr" >&2; exit 1 ;;
      error)   echo "WARNING: $name reported an error at startup - hc read $addr" >&2; exit 1 ;;
    esac
  done
  echo "WARNING: $name started but reported no working status within 60s - hc read $addr" >&2
  exit 1
fi

# Pin the window to the COORDINATOR's session (resolved from this pane), never
# whatever session happens to be active in another attached client. Address the
# window by id afterwards so a same-name window elsewhere can't be hit.
sess="$(tmux display-message -p ${TMUX_PANE:+-t "$TMUX_PANE"} '#{session_id}')"
win_id="$(tmux new-window -dP -F '#{window_id}' -t "${sess}:" -n "$name" -c "$workdir")" || exit 2
tmux send-keys -t "$win_id" "claude --dangerously-skip-permissions ${model_args[*]} ${extra_args[*]:-} \"\$(cat $(printf '%q' "$brief"))\"" Enter

# Verify the session came up and began processing the brief.
for _ in $(seq 1 12); do
  sleep 5
  p="$(tmux capture-pane -t "$win_id" -p 2>/dev/null)"
  if printf '%s' "$p" | grep -qE '\([0-9]+m? ?[0-9]*s? ?·|bypass permissions'; then
    echo "spawned $name (window '$name', cwd $workdir)"
    exit 0
  fi
done

echo "WARNING: $name window created but no claude activity detected - inspect the pane" >&2
exit 1
