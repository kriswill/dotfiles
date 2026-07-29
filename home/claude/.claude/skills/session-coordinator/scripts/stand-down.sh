#!/usr/bin/env bash
# stand-down.sh <scratch-dir> [worktree-dir...]
#
# Step-6 stand-down checklist, deterministically: before dismissing the team,
# verify nothing is about to be lost or left dangling. Checks:
#
#   - heavy.lock free (a held lock means a run is live or a holder crashed);
#   - each worktree clean (`git status --porcelain` empty);
#   - each worktree fully pushed (no commit unreachable from every remote
#     ref — catches unpushed work regardless of upstream configuration).
#
# Prints ok/FAIL per item. Exit codes: 0 all clear, 1 issues found, 2 usage.
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

  g push -q origin work 2>/dev/null
  mkdir "$tmp/scratch/heavy.lock" && echo "ghost: run (pid 1)" > "$tmp/scratch/heavy.lock/owner"
  out="$("$self" "$tmp/scratch" "$tmp/wt")"; rc=$?
  [ "$rc" = 1 ] && printf '%s' "$out" | grep -q "heavy.lock still held" \
    || { echo "self-test: FAIL held lock not flagged (rc=$rc)"; fail=1; }

  [ "$fail" = 0 ] && echo "self-test: OK"
  exit "$fail"
fi

scratch="${1:?usage: stand-down.sh <scratch-dir> [worktree-dir...]}"
shift
issues=0

if [ -d "$scratch/heavy.lock" ]; then
  echo "FAIL heavy.lock still held: $(cat "$scratch/heavy.lock/owner" 2>/dev/null || echo '(no owner file)')"
  issues=1
else
  echo "ok   heavy.lock free"
fi

for wt in "$@"; do
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
