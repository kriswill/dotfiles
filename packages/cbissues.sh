#!/usr/bin/env bash
# cbissues — browse a Codeberg (Forgejo) repo's issues.
#
#   usage: cbissues [owner/repo] [--state open|closed|all] [--plain]
#
# With no repo argument it infers one from the current checkout's codeberg.org
# git remote. Default view is an interactive fzf master-detail: the left list
# shows "#<n> [STATE] title", the right pane previews the full issue, and typing
# fuzzy-matches across titles, labels AND bodies. Enter opens the highlighted
# issue in the browser. --plain prints a scriptable summary table.
#
# Public repos are read anonymously; a private repo transparently falls back to
# the 1Password token (one unlock), same pointer as cbissue.
#
# Packaged by packages/cbissues.nix. `op` resolves from the ambient PATH; the
# rest (curl/jq/fzf/git/xdg-utils/util-linux/coreutils) are pinned there.
set -euo pipefail

ref="${CBISSUE_TOKEN_REF:-op://Private/3htxxhinni5u5mzz5oguowunii/zfptfg4lpdernsrst4kgaxicge}"
api="https://codeberg.org/api/v1"

usage() { echo "usage: cbissues [owner/repo] [--state open|closed|all] [--plain]" >&2; }

state=open
plain=0
positional=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --state)
      shift
      state="${1:-}"
      ;;
    --state=*) state="${1#*=}" ;;
    --plain) plain=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        positional+=("$1")
        shift
      done
      break
      ;;
    -*)
      echo "cbissues: unknown option: $1" >&2
      usage
      exit 2
      ;;
    *) positional+=("$1") ;;
  esac
  shift
done
if [ "${#positional[@]}" -gt 0 ]; then set -- "${positional[@]}"; else set --; fi
repo="${1:-}"

case "$state" in
  open | closed | all) ;;
  *)
    echo "cbissues: --state must be open|closed|all" >&2
    exit 2
    ;;
esac

# Infer repo from the current checkout's codeberg.org remote when not given.
if [ -z "$repo" ]; then
  url="$(git remote get-url origin 2>/dev/null || true)"
  case "$url" in
    *codeberg.org*)
      u="${url#*codeberg.org}"
      u="${u#[:/]}"
      repo="${u%.git}"
      ;;
  esac
fi
[ -n "$repo" ] || {
  usage
  exit 2
}

tmp="$(mktemp)"
data="$(mktemp)"
tmpd="$(mktemp -d)"
trap 'rm -rf "$tmp" "$data" "$tmpd"' EXIT

# Page through the issues. Try anonymously; only reach for the token if the repo
# turns out to be private (so public repos need no 1Password unlock).
tok=""
need_auth=0
fetch_page() {
  local q code
  q="repos/$repo/issues?type=issues&state=$state&limit=50&page=$1"
  if [ "$need_auth" = 0 ]; then
    code="$(curl -s -o "$tmp" -w '%{http_code}' "$api/$q")"
    case "$code" in
      401 | 403 | 404)
        need_auth=1
        [ -n "$tok" ] || tok="$(op read "$ref")"
        ;;
    esac
  fi
  if [ "$need_auth" = 1 ]; then
    code="$(printf 'header = "Authorization: token %s"\n' "$tok" \
      | curl -s --config - -o "$tmp" -w '%{http_code}' "$api/$q")"
  fi
  if [ "$code" != 200 ]; then
    echo "cbissues: GET issues -> HTTP $code" >&2
    jq -r '.message // empty' "$tmp" 2>/dev/null >&2 || true
    return 1
  fi
}

echo '[]' > "$data"
page=1
while :; do
  fetch_page "$page" || exit 1
  cnt="$(jq 'length' "$tmp")"
  jq -s '.[0] + .[1]' "$data" "$tmp" > "$tmp.merged" && mv "$tmp.merged" "$data"
  [ "$cnt" -lt 50 ] && break
  page=$((page + 1))
  [ "$page" -gt 10 ] && break # safety cap (~500 issues)
done

total="$(jq 'length' "$data")"
if [ "$total" -eq 0 ]; then
  echo "no $state issues in $repo"
  exit 0
fi

# --- plain (non-interactive) summary table ---
if [ "$plain" = 1 ]; then
  jq -r '.[] | [ "#" + (.number|tostring),
                 (.state|ascii_upcase),
                 ((.labels|map(.name)|join(",")) | if . == "" then "-" else . end),
                 .title ] | @tsv' "$data" \
    | column -t -s "$(printf '\t')"
  exit 0
fi

# --- interactive master-detail ---
# fzf line = <num>\t<blob>. The number (field 1) is kept only for {1} in the
# preview/open bindings; everything that should be searchable AND shown lives in
# field 2: "#<n> [STATE] title {labels} body". --with-nth 2 displays field 2 and
# — the key fzf quirk — searches exactly what it displays, so titles, labels and
# bodies must all sit in that one field to be fuzzy-matchable. In the narrow list
# pane the long body just truncates off the right edge; the preview shows it in
# full. (Don't try --with-nth + --nth to hide the body while still searching it —
# combining those two flags makes fzf 0.73 match nothing.)
prev="$tmpd/preview"
cat > "$prev" <<'PREVIEW'
#!/bin/sh
# $1 = issue number, $2 = data json
jq -r --arg n "$1" '
  .[] | select((.number|tostring) == $n) |
  "#\(.number)  [\(.state)]  by \(.user.login // "?")",
  "\(.title)",
  (if (.labels|length) > 0 then "labels: " + (.labels|map(.name)|join(", ")) else "labels: (none)" end),
  "updated: \(.updated_at)",
  "\(.html_url)",
  "",
  (.body // "(no description)")
' "$2"
PREVIEW
chmod +x "$prev"

jq -r '.[] | (.number|tostring) as $n |
  [ $n,
    "#" + $n + "  [" + (.state|ascii_upcase) + "]  " + .title
      + (if (.labels|length) > 0 then "  {" + (.labels|map(.name)|join(",")) + "}" else "" end)
      + "  " + ((.body // "") | gsub("[\\r\\n]+"; " ")) ]
  | @tsv' "$data" \
  | fzf \
      --delimiter '\t' \
      --with-nth 2 \
      --reverse \
      --no-hscroll \
      --header "enter: open in browser · esc: quit    ($total $state issue(s) in $repo)" \
      --preview "$prev {1} $data" \
      --preview-window 'right,60%,wrap' \
      --bind "enter:execute-silent(xdg-open 'https://codeberg.org/$repo/issues/{1}')" \
    > /dev/null || true
