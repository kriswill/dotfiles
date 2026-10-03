#!/usr/bin/env bash
# slack-leave-devopsinc — leave every Slack `devopsinc-N` channel (N >= 1000)
# that the PagerDuty incident routine keeps auto-adding you to.
#
#   usage: slack-leave-devopsinc [-n|--dry-run] [--notify]
#
# Talks to the Slack Web API directly — users.conversations finds the channels
# you're in, conversations.leave leaves each match — so Slack.app needn't be
# running and no UI is scripted (no Accessibility permission). Needs a Slack
# *user* token (xoxp-…) with scopes channels:read, groups:read, channels:write,
# groups:write, taken from $SLACK_LEAVE_TOKEN or else the login Keychain item
# with service `slack-leave-devopsinc`; store it once with
#
#   security add-generic-password -U -a "$USER" -s slack-leave-devopsinc -w
#
# The token is passed to curl via printf (a shell builtin), so it never lands
# on disk or in a process argument list. --notify also reports the outcome as a
# macOS notification; the "Leave devopsinc Channels" app (Spotlight) runs it
# that way. Exit status is 1 if any channel couldn't be left.
#
# Packaged by pkgs/slack-leave-devopsinc.nix (writeShellApplication pins
# curl/jq; `security` and `osascript` are macOS system binaries, by abs path).
set -euo pipefail

# Colors (AGENTS.md shell convention).
# shellcheck disable=SC2034 # full palette defined per convention; not all used
RED=$'\e[31m' GREEN=$'\e[32m' YELLOW=$'\e[33m' BLUE=$'\e[34m' NC=$'\e[0m'

PREFIX="devopsinc-"
MIN_N=1000
KEYCHAIN_SERVICE="slack-leave-devopsinc"
API="https://slack.com/api"

usage() { echo "usage: slack-leave-devopsinc [-n|--dry-run] [--notify]" >&2; }

dry_run=0
notify=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -n | --dry-run) dry_run=1 ;;
    --notify) notify=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "${RED}slack-leave-devopsinc: unknown argument: $1${NC}" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

# notify MESSAGE — macOS notification when --notify was given. The message goes
# in as an argv item, never spliced into the AppleScript source.
notify() {
  [ "$notify" -eq 1 ] || return 0
  /usr/bin/osascript \
    -e 'on run argv' \
    -e 'display notification (item 2 of argv) with title (item 1 of argv)' \
    -e 'end run' \
    "Slack: leave ${PREFIX}N" "$1" >/dev/null 2>&1 || true
}

fail() {
  echo "${RED}slack-leave-devopsinc: $1${NC}" >&2
  notify "$1"
  exit 1
}

tok="${SLACK_LEAVE_TOKEN:-}"
if [ -z "$tok" ]; then
  tok="$(/usr/bin/security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)" ||
    fail "no Slack token: set \$SLACK_LEAVE_TOKEN or add Keychain item '$KEYCHAIN_SERVICE'"
fi

auth() { printf 'header = "Authorization: Bearer %s"\n' "$tok"; }

# api METHOD [curl args...] — call a Web API method (form POST, or a GET query
# with -G) and print its JSON reply. Returns 1 when Slack answers ok:false (or curl fails, with an
# empty reply). --retry waits out 429s, honouring Slack's Retry-After header.
api() {
  local method="$1" resp
  shift
  resp="$(auth | curl -sS --retry 5 --config - "$@" "$API/$method")" || return 1
  printf '%s\n' "$resp"
  [ "$(printf '%s' "$resp" | jq -r '.ok')" = true ]
}

# slack_error REPLY — Slack's error code, plus the missing scope if that's why.
slack_error() {
  [ -n "$1" ] || {
    echo "request failed"
    return 0
  }
  printf '%s' "$1" | jq -r '(.error // "request failed") + (if .needed then " (needs scope: \(.needed))" else "" end)' 2>/dev/null ||
    echo "request failed"
}

# --- find: every page of the channels you're in, filtered to PREFIX + N >= MIN_N ---
found=() # "<channel id>\t<channel name>"
cursor=""
while :; do
  page_args=(
    -G # users.conversations is a read method: GET with a query string
    --data-urlencode "types=public_channel,private_channel"
    --data-urlencode "exclude_archived=true"
    --data-urlencode "limit=200"
  )
  [ -z "$cursor" ] || page_args+=(--data-urlencode "cursor=$cursor")
  resp="$(api users.conversations "${page_args[@]}")" ||
    fail "users.conversations: $(slack_error "$resp")"
  mapfile -t page < <(printf '%s' "$resp" | jq -r --arg p "$PREFIX" --argjson min "$MIN_N" '
    .channels[]
    | select(.name | startswith($p))
    | (.name | ltrimstr($p)) as $n
    | select($n | test("^[0-9]+$"))
    | select(($n | tonumber) >= $min)
    | "\(.id)\t\(.name)"')
  found+=("${page[@]}")
  cursor="$(printf '%s' "$resp" | jq -r '.response_metadata.next_cursor // ""')"
  [ -n "$cursor" ] || break
done

if [ "${#found[@]}" -eq 0 ]; then
  echo "${BLUE}no ${PREFIX}N channels to leave${NC}"
  notify "No ${PREFIX}N channels to leave"
  exit 0
fi

# --- leave: one conversations.leave per match; a failure doesn't stop the rest ---
left=()
failed=()
for entry in "${found[@]}"; do
  id="${entry%%$'\t'*}"
  name="${entry#*$'\t'}"
  if [ "$dry_run" -eq 1 ]; then
    echo "${YELLOW}would leave${NC} #$name"
    left+=("$name")
  elif resp="$(api conversations.leave --data-urlencode "channel=$id")"; then
    echo "${GREEN}left${NC} #$name"
    left+=("$name")
  else
    err="$(slack_error "$resp")"
    echo "${RED}failed${NC} #$name: $err" >&2
    failed+=("$name ($err)")
  fi
done

join() {
  local out="" s
  for s in "$@"; do out+="${out:+, }$s"; done
  printf '%s' "$out"
}

if [ "$dry_run" -eq 1 ]; then
  summary="Would leave ${#left[@]}: $(join "${left[@]}")"
elif [ "${#left[@]}" -gt 0 ]; then
  summary="Left ${#left[@]}: $(join "${left[@]}")"
else
  summary="Left none"
fi
[ "${#failed[@]}" -eq 0 ] || summary+=" — failed ${#failed[@]}: $(join "${failed[@]}")"
notify "$summary"
[ "${#failed[@]}" -eq 0 ]
