#!/usr/bin/env bash
# Tests the kitten shim against a stand-in kitten that records its arguments.
#
#   usage: kitten-shim.sh <bin directory of the shim>
#
# Run by the flake's `checks.<system>.kitten-shim`, in the build sandbox,
# which has no controlling terminal. The "no terminal" case relies on that,
# so run it through `nix flake check` rather than from a shell. The cases
# that need a terminal make one with script(1) and run on Linux only.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

shim=${1:?usage: kitten-shim.sh <bin directory of the shim>}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The stand-in: writes its arguments, one per line, to $KITTEN_ARGV.
mkdir "$work/real" "$work/link" "$work/empty"
export KITTEN_ARGV=$work/argv
cat >"$work/real/kitten" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$KITTEN_ARGV"
EOF
chmod +x "$work/real/kitten"
ln -s "$shim/kitten" "$work/link/kitten"

# Each case gets a PATH of its own making, so a kitten installed on the
# machine running this can never be the one that answers. The shim brings
# its own coreutils; script(1) and timeout are looked up here, once.
timeout=$(command -v timeout)
script=$(command -v script || true)
failures=0

# expect <name> <expected arguments, space separated, as an extended regex>
expect() {
  local name=$1 want=$2 got
  got=$(tr '\n' ' ' <"$KITTEN_ARGV" 2>/dev/null | sed 's/ $//' || true)
  if [[ $got =~ ^${want}$ ]]; then
    printf '%b\n' "${GREEN}ok${NC}    $name"
  else
    printf '%b\n' "${RED}FAIL${NC}  $name"
    printf '        want: %s\n        got:  %s\n' "$want" "$got"
    failures=$((failures + 1))
  fi
  rm -f "$KITTEN_ARGV"
}

printf '%b\n' "${BLUE}kitten shim: $shim${NC}"

# Outside herdr-core nothing changes, icat included.
env -u HC_TERMINAL_ID PATH="$shim:$work/real" \
  kitten icat -n --align=left --place=27x20@0x0 --scale-up logo.png
expect "outside herdr-core: icat passes through" \
  "icat -n --align=left --place=27x20@0x0 --scale-up logo.png"

# In herdr-core, only icat is touched.
HC_TERMINAL_ID=t1 PATH="$shim:$work/real" kitten --version
expect "herdr-core: other commands pass through" "--version"

# No terminal to ask (the sandbox has none): icat passes through.
HC_TERMINAL_ID=t1 PATH="$shim:$work/real" kitten icat -n logo.png </dev/null
expect "herdr-core, no terminal: icat passes through" "icat -n logo.png"

# A link to the shim earlier on PATH must not be taken for the real kitten.
HC_TERMINAL_ID=t1 PATH="$work/link:$shim:$work/real" kitten --version
expect "a link to the shim is skipped" "--version"

# No real kitten anywhere: 127, like a missing command.
status=0
HC_TERMINAL_ID=t1 PATH="$shim:$work/empty" kitten icat logo.png 2>"$work/err" || status=$?
if [[ $status -eq 127 ]] && grep -q 'not found on PATH' "$work/err"; then
  printf '%b\n' "${GREEN}ok${NC}    no real kitten: exits 127"
else
  printf '%b\n' "${RED}FAIL${NC}  no real kitten: exits 127 (got $status: $(cat "$work/err"))"
  failures=$((failures + 1))
fi

if [[ $(uname) == Linux && -n $script ]]; then
  # in_terminal <command>: run it on a terminal of its own, with this
  # script's stdin typed into that terminal. Ten seconds is the limit for a
  # shim that waits on a terminal for ever.
  in_terminal() {
    HC_TERMINAL_ID=t1 PATH="$shim:$work/real" SHELL=$BASH \
      "$timeout" 10 "$script" -qec "$1" /dev/null >/dev/null
  }

  # script(1) gives the shim a terminal and types its stdin into it. The
  # reply to `CSI 14 t` is typed before the shim asks; it waits in the
  # terminal's input until the shim reads.
  printf '\033[4;520;324t' | in_terminal "kitten icat -n --place=27x20@0x0 logo.png" || true
  expect "herdr-core, terminal answers 520x324: stream at that size" \
    "icat --transfer-mode=stream --use-window-size=[0-9]+,[0-9]+,324,520 -n --place=27x20@0x0 logo.png"

  # A terminal that says nothing: after the wait, icat passes through.
  in_terminal "kitten icat -n logo.png" </dev/null || true
  expect "herdr-core, terminal is silent: icat passes through" "icat -n logo.png"

  # A reply that isn't a size report changes nothing either.
  printf '\033[8;46;123t' | in_terminal "kitten icat -n logo.png" || true
  expect "herdr-core, terminal answers something else: icat passes through" "icat -n logo.png"
else
  printf '%b\n' "${YELLOW}skip${NC}  terminal cases (Linux with script(1) only)"
fi

if [[ $failures -gt 0 ]]; then
  printf '%b\n' "${RED}$failures failed${NC}"
  exit 1
fi
printf '%b\n' "${GREEN}all passed${NC}"
