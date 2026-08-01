#!/usr/bin/env bash
# stand-down.sh <scratch-dir> [--policy <file>] [worktree-dir...]
#
# Step-6 stand-down checklist, deterministically: before dismissing the team,
# verify nothing is about to be lost or left dangling. Checks:
#
#   - heavy.lock free (a held lock means a run is live or a holder crashed);
#   - each worktree clean (`git status --porcelain` empty);
#   - each worktree fully pushed (no commit unreachable from every remote
#     ref — catches unpushed work regardless of upstream configuration).
#
# THE PUSHED CHECK IS POLICY-DEPENDENT. Under `no-github` and `local-merge`,
# unpushed commits are the DESIGNED state - there may be no remote at all, in
# which case `rev-list --not --remotes` counts every commit and the check
# false-FAILs the whole mission (3 spurious FAILs in one local-merge run). The
# mission policy is read from <scratch>/mission-policy automatically (the path
# SKILL.md Step 1 writes it to); `--policy <file>` overrides. Under those two
# policies the pushed check downgrades to `info` and does not set the exit code.
# An unreadable or absent policy file means strict behaviour, which is the safe
# default: a missing policy should never silently excuse unpushed work.
#
# Prints ok/FAIL/info per item. Exit codes: 0 all clear, 1 issues found, 2 usage.
set -u

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

if [ "${1:-}" = "--self-test" ]; then
  fail=0
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  mkdir "$tmp/scratch"
  git init -q --bare "$tmp/origin.git"
  git clone -q "$tmp/origin.git" "$tmp/wt" 2>/dev/null
  g() { git -C "$tmp/wt" -c user.email=s@t -c user.name=selftest -c commit.gpgsign=false "$@"; }
  g checkout -q -b work
  g commit -q --allow-empty -m one
  g push -q -u origin work 2>/dev/null

  "$self" "$tmp/scratch" "$tmp/wt" >/dev/null; rc=$?
  [ "$rc" = 0 ] || { echo "self-test: FAIL clean+pushed rc=$rc (want 0)"; fail=1; }

  echo dirty > "$tmp/wt/f"
  out="$("$self" "$tmp/scratch" "$tmp/wt")"; rc=$?
  [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "uncommitted" \
    || { echo "self-test: FAIL dirty worktree not flagged (rc=$rc)"; fail=1; }

  g add f && g commit -q -m two
  out="$("$self" "$tmp/scratch" "$tmp/wt")"; rc=$?
  [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "not on any remote" \
    || { echo "self-test: FAIL unpushed commit not flagged (rc=$rc)"; fail=1; }

  # The unpushed commit from the previous case is still present. Under a
  # local-merge / no-github policy that is the DESIGNED state and must NOT fail.
  # Both directions are asserted: the policy must downgrade it, and a strict
  # policy must still catch it - a fix that simply stopped checking would pass
  # the first assertion and fail the second.
  echo local-merge > "$tmp/scratch/mission-policy"
  out="$("$self" "$tmp/scratch" "$tmp/wt")"; rc=$?
  [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "expected under 'local-merge'" \
    || { echo "self-test: FAIL local-merge did not downgrade unpushed (rc=$rc)"; fail=1; }

  echo no-github > "$tmp/scratch/mission-policy"
  "$self" "$tmp/scratch" "$tmp/wt" >/dev/null; rc=$?
  [ "$rc" = 0 ] || { echo "self-test: FAIL no-github did not downgrade unpushed (rc=$rc)"; fail=1; }

  # A policy that DOES expect pushes must still fail on the same repo state.
  echo prs-user-merge > "$tmp/scratch/mission-policy"
  out="$("$self" "$tmp/scratch" "$tmp/wt")"; rc=$?
  [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "not on any remote" \
    || { echo "self-test: FAIL prs-user-merge wrongly excused unpushed (rc=$rc)"; fail=1; }

  # An explicit --policy overrides auto-detection.
  echo local-merge > "$tmp/override-policy"
  "$self" "$tmp/scratch" --policy "$tmp/override-policy" "$tmp/wt" >/dev/null; rc=$?
  [ "$rc" = 0 ] || { echo "self-test: FAIL --policy override not honoured (rc=$rc)"; fail=1; }

  # An unreadable policy file must fall back to STRICT, never to permissive.
  "$self" "$tmp/scratch" --policy "$tmp/does-not-exist" "$tmp/wt" >/dev/null; rc=$?
  [ "$rc" = 1 ] || { echo "self-test: FAIL missing policy file did not fail strict (rc=$rc)"; fail=1; }

  # THE ACTUAL REPORTED FAILURE MODE: a repo with NO REMOTE AT ALL, which is
  # normal under no-github. `rev-list HEAD --not --remotes` then counts EVERY
  # commit, so the pre-fix script failed the designed state. Asserted in both
  # directions on the same repo.
  git init -q "$tmp/wt-noremote"
  gn() { git -C "$tmp/wt-noremote" -c user.email=s@t -c user.name=selftest -c commit.gpgsign=false "$@"; }
  gn commit -q --allow-empty -m one
  echo no-github > "$tmp/scratch/mission-policy"
  out="$("$self" "$tmp/scratch" "$tmp/wt-noremote")"; rc=$?
  [ "$rc" = 0 ] && printf '%s' "$out" | grep -q "expected under 'no-github'" \
    || { echo "self-test: FAIL no-remote repo not downgraded under no-github (rc=$rc)"; fail=1; }

  rm -f "$tmp/scratch/mission-policy"
  out="$("$self" "$tmp/scratch" "$tmp/wt-noremote")"; rc=$?
  [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "not on any remote" \
    || { echo "self-test: FAIL no-remote repo not flagged under strict default (rc=$rc)"; fail=1; }

  g push -q origin work 2>/dev/null
  mkdir "$tmp/scratch/heavy.lock" && echo "ghost: run (pid 1)" > "$tmp/scratch/heavy.lock/owner"
  out="$("$self" "$tmp/scratch" "$tmp/wt")"; rc=$?
  [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "heavy.lock still held" \
    || { echo "self-test: FAIL held lock not flagged (rc=$rc)"; fail=1; }

  [ "$fail" = 0 ] && echo "self-test: OK"
  exit "$fail"
fi

scratch=""
policy_file=""
wts=()
while [ $# -gt 0 ]; do
  case "$1" in
    --policy)
      policy_file="${2:?--policy needs a file}"
      shift 2 ;;
    *)
      if [ -z "$scratch" ]; then scratch="$1"; else wts+=("$1"); fi
      shift ;;
  esac
done
[ -n "$scratch" ] || { echo "usage: stand-down.sh <scratch-dir> [--policy <file>] [worktree-dir...]" >&2; exit 2; }

# Auto-detect the mission policy at its conventional path unless overridden.
if [ -z "$policy_file" ] && [ -f "$scratch/mission-policy" ]; then
  policy_file="$scratch/mission-policy"
fi
policy=""
if [ -n "$policy_file" ] && [ -r "$policy_file" ]; then
  policy="$(tr -d '[:space:]' < "$policy_file" 2>/dev/null || true)"
fi
case "$policy" in
  no-github|local-merge) remote_optional=1 ;;
  *)                     remote_optional=0 ;;
esac
[ -n "$policy" ] && echo "---  mission policy: $policy"

issues=0

if [ -d "$scratch/heavy.lock" ]; then
  echo "FAIL heavy.lock still held: $(cat "$scratch/heavy.lock/owner" 2>/dev/null || echo '(no owner file)')"
  issues=1
else
  echo "ok   heavy.lock free"
fi

for wt in ${wts[@]+"${wts[@]}"}; do
  if ! git -C "$wt" rev-parse --git-dir >/dev/null 2>&1; then
    echo "FAIL $wt: not a git repo"
    issues=1
    continue
  fi
  dirty="$(git -C "$wt" status --porcelain)"
  if [ -n "$dirty" ]; then
    echo "FAIL $wt: uncommitted changes:"
    printf '%s\n' "$dirty" | sed 's/^/       /'
    issues=1
  else
    echo "ok   $wt: clean"
  fi
  unpushed="$(git -C "$wt" rev-list --count HEAD --not --remotes 2>/dev/null || echo '?')"
  if [ "$unpushed" = 0 ]; then
    echo "ok   $wt: fully pushed"
  elif [ "$remote_optional" = 1 ]; then
    echo "info $wt: $unpushed commit(s) not on any remote - expected under '$policy'"
  else
    echo "FAIL $wt: $unpushed commit(s) not on any remote"
    issues=1
  fi
done

if [ "$issues" = 0 ]; then
  echo "stand-down: ALL CLEAR"
else
  echo "stand-down: issues found - resolve before dismissing teammates"
fi
exit "$issues"
