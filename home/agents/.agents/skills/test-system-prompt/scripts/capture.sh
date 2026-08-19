#!/usr/bin/env bash
# Capture the literal system prompt Claude Code sends, via the ccglass proxy.
#
#   capture.sh <outdir> [claude-args...]
#
# Env:
#   CFG   config dir to test under (default: $CLAUDE_CONFIG_DIR, else ~/.claude-work)
#
# Two invocation traps this wraps:
#
#   1. `ccglass claude --dir X -- -p hi --settings '{...}'` DROPS the trailing
#      flags. The capture succeeds and looks fine, but the config under test was
#      never applied — you diff two identical prompts and conclude "no effect".
#      `ccglass run --provider claude ... -- claude <args>` passes them intact.
#
#   2. A parent Claude Code session exports CLAUDE_CONFIG_DIR. Inherited, it sends
#      every run down the wrapper's passthrough branch and pins the profile, so you
#      silently test the wrong config. Set it explicitly here, never inherit it.
#
# ccglass execs the binary directly rather than through a shell, so the profile-selector
# `claude` shell function never runs and its injected launch flags (e.g.
# --disallowedTools) cannot contaminate the measurement. Do not write `command claude`
# here: `command` is a shell builtin, not an executable, and the spawn fails.

set -euo pipefail

OUT="${1:?usage: capture.sh <outdir> [claude-args...]}"
shift

CFG="${CFG:-${CLAUDE_CONFIG_DIR:-$HOME/.claude-work}}"

command -v ccglass >/dev/null || { echo "ccglass not on PATH" >&2; exit 127; }

rm -rf "$OUT"
mkdir -p "$OUT"

# cd to a neutral dir so the project CLAUDE.md under test is chosen deliberately
# (pass --add-dir or run from the project when you DO want it).
cd "${CAPTURE_CWD:-/tmp}"

CLAUDE_CONFIG_DIR="$CFG" ccglass run \
  --provider claude \
  --no-open \
  --dir "$OUT" \
  -- claude -p "hi" "$@" >/dev/null 2>&1 || true

if ! find "$OUT" -name '*.json' -not -path '*/blobs/*' | grep -q .; then
  echo "capture produced no requests — is ccglass able to reach the API?" >&2
  exit 1
fi
echo "captured -> $OUT"
