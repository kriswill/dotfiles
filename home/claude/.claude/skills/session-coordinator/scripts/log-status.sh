#!/usr/bin/env bash
# log-status.sh [--retract] <status-file> <message...>
#
# Teammate status-line appender. Stamps wall-clock time (date +%H:%M) and the
# current worktree's HEAD SHA itself, so neither is ever written from a
# model's memory: self-stamped times have drifted hours behind wall clock in
# a live mission, and one recalled commit SHA cited an object that did not
# exist. Derives the teammate name from the file name (status-<name>.md),
# collapses the message to ONE line (the status stream is line-oriented),
# appends, and echoes the appended line:
#
#   [17:50] impl @2e3503f: t12 rig rebuilt; 3/3 green; opening PR
#
# --retract prefixes the loud retraction banner — a withdrawn claim must be
# as loud as the claim it withdraws:
#
#   [18:02] impl @2e3503f: *** RETRACTION *** t01 unsound (nested client ate
#   the chords); t02-t11 survive
#
# Run it from your worktree so the SHA is your branch's HEAD. Outside a git
# repo the @sha field is omitted. Exit codes: 0 appended, 2 usage error.
set -u

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

if [ "${1:-}" = "--self-test" ]; then
  fail=0
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  mkdir "$tmp/repo" "$tmp/plain"
  git -C "$tmp/repo" init -q || { echo "self-test: git init failed"; exit 1; }
  git -C "$tmp/repo" -c user.email=s@t -c user.name=selftest -c commit.gpgsign=false \
    commit -q --allow-empty -m selftest || { echo "self-test: git commit failed"; exit 1; }
  f="$tmp/status-selftest.md"

  (cd "$tmp/repo" && "$self" "$f" "hello world") >/dev/null
  grep -qE '^\[[0-9]{2}:[0-9]{2}\] selftest @[0-9a-f]{4,}: hello world$' "$f" \
    || { echo "self-test: FAIL stamped line: $(tail -1 "$f")"; fail=1; }

  (cd "$tmp/repo" && "$self" --retract "$f" "t01 unsound; t02 survives") >/dev/null
  grep -qE '^\[[0-9]{2}:[0-9]{2}\] selftest @[0-9a-f]{4,}: \*\*\* RETRACTION \*\*\* t01 unsound; t02 survives$' "$f" \
    || { echo "self-test: FAIL retraction line: $(tail -1 "$f")"; fail=1; }

  (cd "$tmp/plain" && "$self" "$f" "no repo here") >/dev/null
  grep -qE '^\[[0-9]{2}:[0-9]{2}\] selftest: no repo here$' "$f" \
    || { echo "self-test: FAIL non-git line: $(tail -1 "$f")"; fail=1; }

  (cd "$tmp/plain" && "$self" "$f" "$(printf 'line1\nline2')") >/dev/null
  [ "$(wc -l < "$f" | tr -d ' ')" = 4 ] \
    || { echo "self-test: FAIL line count $(wc -l < "$f") (want 4 - newline not collapsed)"; fail=1; }
  grep -q 'line1 line2' "$f" || { echo "self-test: FAIL newline collapse"; fail=1; }

  [ "$fail" = 0 ] && echo "self-test: OK"
  exit "$fail"
fi

retract=0
if [ "${1:-}" = "--retract" ]; then retract=1; shift; fi
file="${1:?usage: log-status.sh [--retract] <status-file> <message...>}"
shift
msg="${*:-}"
[ -n "$msg" ] || { echo "log-status.sh: empty message" >&2; exit 2; }

base="$(basename "$file")"
name="${base#status-}"; name="${name%.*}"
sha="$(git rev-parse --short HEAD 2>/dev/null || true)"

msg="$(printf '%s' "$msg" | tr '\n\r' '  ' | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//')"
[ "$retract" = 1 ] && msg="*** RETRACTION *** $msg"

line="[$(date +%H:%M)] $name${sha:+ @$sha}: $msg"
printf '%s\n' "$line" >> "$file" || { echo "log-status.sh: cannot append to $file" >&2; exit 2; }
printf '%s\n' "$line"
