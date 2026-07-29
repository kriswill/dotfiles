#!/usr/bin/env bash
# with-heavy-lock.sh [--poll S] <scratch-dir> "<who>: <purpose>" -- <cmd...>
#
# Canonical wrapper for the mission's exclusive heavy-run lock (benchmarks,
# big builds, memory measurement). Replaces the recipe every teammate used to
# re-type from the brief — and get subtly wrong. Semantics:
#
#   - mkdir-mutex on <scratch>/heavy.lock; waits (default poll 10s) while
#     held, reporting the current holder every ~minute;
#   - owner file records who/purpose/pid/since, so contention is diagnosable;
#   - trap-release on EXIT/INT/TERM;
#   - STALE-HOLDER STEALING: if the recorded pid is dead the holder died
#     without its trap (kill -9, crash) — the lock is reclaimed via an atomic
#     rename instead of stalling the mission forever. A lock with no owner
#     file is never stolen (conservative: waiting is the safe failure mode);
#   - the wrapped command's stdout/stderr and EXIT CODE pass through
#     untouched; all lock chatter goes to stderr.
#
# Exit codes: the command's own rc; 2 usage error.
set -u

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
now() { date +%H:%M; }

if [ "${1:-}" = "--self-test" ]; then
  fail=0
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

  # 1. lock held during the command, owner correct, released after, stdout passes
  out="$("$self" "$tmp" "selftest: basic" -- cat "$tmp/heavy.lock/owner" 2>/dev/null)"
  printf '%s' "$out" | grep -q "selftest: basic (pid" || { echo "self-test: FAIL owner file during run: '$out'"; fail=1; }
  [ ! -d "$tmp/heavy.lock" ] || { echo "self-test: FAIL lock not released"; fail=1; }

  # 2. exit code propagation
  "$self" "$tmp" "selftest: rc" -- sh -c 'exit 7' 2>/dev/null; rc=$?
  [ "$rc" = 7 ] || { echo "self-test: FAIL rc propagation rc=$rc (want 7)"; fail=1; }

  # 3. stale-holder stealing (dead pid)
  mkdir "$tmp/heavy.lock" && echo "ghost: old run (pid 99999999)" > "$tmp/heavy.lock/owner"
  "$self" --poll 1 "$tmp" "selftest: steal" -- true 2>"$tmp/err"; rc=$?
  [ "$rc" = 0 ] && grep -q "STOLE" "$tmp/err" || { echo "self-test: FAIL stale lock not stolen (rc=$rc)"; fail=1; }

  # 4. live contention: waits for a living holder to release
  ( mkdir "$tmp/heavy.lock" && echo "holder: bg (pid $$)" > "$tmp/heavy.lock/owner" \
    && sleep 2 && rm -rf "$tmp/heavy.lock" ) &
  sleep 0.3
  t0="$(date +%s)"
  "$self" --poll 1 "$tmp" "selftest: wait" -- true 2>/dev/null; rc=$?
  t1="$(date +%s)"
  wait
  [ "$rc" = 0 ] || { echo "self-test: FAIL contention run rc=$rc"; fail=1; }
  [ $((t1 - t0)) -ge 1 ] || { echo "self-test: FAIL did not wait for live holder"; fail=1; }

  [ "$fail" = 0 ] && echo "self-test: OK"
  exit "$fail"
fi

poll=10
if [ "${1:-}" = "--poll" ]; then poll="${2:?--poll needs seconds}"; shift 2; fi
scratch="${1:?usage: with-heavy-lock.sh [--poll S] <scratch-dir> \"<who>: <purpose>\" -- <cmd...>}"
who="${2:?missing \"<who>: <purpose>\"}"
[ "${3:-}" = "--" ] || { echo "with-heavy-lock.sh: expected -- before the command" >&2; exit 2; }
shift 3
[ $# -ge 1 ] || { echo "with-heavy-lock.sh: no command given" >&2; exit 2; }
[ -d "$scratch" ] || { echo "with-heavy-lock.sh: scratch dir does not exist: $scratch" >&2; exit 2; }

lock="$scratch/heavy.lock"
tries=0
until mkdir "$lock" 2>/dev/null; do
  owner="$(cat "$lock/owner" 2>/dev/null || echo "(no owner file)")"
  pid="$(printf '%s' "$owner" | sed -n 's/.*(pid \([0-9][0-9]*\).*/\1/p')"
  if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
    # Atomic steal: only one waiter wins the rename; losers loop and retry.
    if mv "$lock" "$lock.stale.$$" 2>/dev/null; then
      rm -rf "$lock.stale.$$"
      echo "[$(now)] heavy.lock: STOLE stale lock from dead holder: $owner" >&2
    fi
    continue
  fi
  tries=$((tries + 1))
  [ $((tries % 6)) -eq 0 ] && echo "[$(now)] heavy.lock: still waiting for holder: $owner" >&2
  sleep "$poll"
done
printf '%s (pid %s, since %s)\n' "$who" "$$" "$(now)" > "$lock/owner"
trap 'rm -rf "$lock"' EXIT INT TERM
echo "[$(now)] heavy.lock: acquired by $who" >&2

"$@"
rc=$?
echo "[$(now)] heavy.lock: released by $who (cmd rc=$rc)" >&2
exit "$rc"
