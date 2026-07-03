#!/usr/bin/env bash
# cbissue — open a Codeberg (Forgejo) issue from the command line.
#
#   usage: cbissue <owner/repo> <title> [body] [-l LABEL]...
#   e.g.   cbissue kriswill/foo "Build is red" "Failing since abc123." -l bug -l "help wanted"
#
# Labels are given by NAME (repeatable -l) and resolved to the repo's Forgejo
# label IDs; an unknown name is a hard error that lists the valid names. The API
# token is read on demand from 1Password and passed to curl via printf (a shell
# builtin), so it never lands on disk or in a process argument list. Requires the
# 1Password CLI (`op`) on PATH, unlocked via the desktop app.
#
# Packaged by pkgs/cbissue.nix (writeShellApplication pins curl/jq/coreutils;
# `op` resolves from the ambient PATH). Override the 1Password reference with
# $CBISSUE_TOKEN_REF.
set -euo pipefail

ref="${CBISSUE_TOKEN_REF:-op://Private/3htxxhinni5u5mzz5oguowunii/zfptfg4lpdernsrst4kgaxicge}"
api="https://codeberg.org/api/v1"

usage() { echo "usage: cbissue <owner/repo> <title> [body] [-l LABEL]..." >&2; }

# --- parse args: positional owner/repo, title, body; repeatable -l/--label ---
labels=()
positional=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -l | --label)
      shift
      [ "$#" -gt 0 ] || {
        echo "cbissue: -l needs a label name" >&2
        exit 2
      }
      labels+=("$1")
      ;;
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
      echo "cbissue: unknown option: $1" >&2
      usage
      exit 2
      ;;
    *) positional+=("$1") ;;
  esac
  shift
done
if [ "${#positional[@]}" -gt 0 ]; then set -- "${positional[@]}"; else set --; fi

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  usage
  exit 2
fi
repo="$1"
title="$2"
body="${3:-}"

# Token: read once into memory only (never disk/argv).
tok="$(op read "$ref")"
auth() { printf 'header = "Authorization: token %s"\n' "$tok"; }

# --- resolve label names -> ids ---
label_ids="[]"
if [ "${#labels[@]}" -gt 0 ]; then
  all="$(auth | curl -s --config - "$api/repos/$repo/labels?limit=100")"
  ids=()
  for name in "${labels[@]}"; do
    id="$(printf '%s' "$all" | jq -r --arg n "$name" 'map(select(.name == $n)) | .[0].id // empty')"
    if [ -z "$id" ]; then
      echo "cbissue: no label named \"$name\" in $repo" >&2
      echo "  available: $(printf '%s' "$all" | jq -r 'map(.name) | join(", ")')" >&2
      exit 1
    fi
    ids+=("$id")
  done
  label_ids="$(printf '%s\n' "${ids[@]}" | jq -s 'map(tonumber)')"
fi

payload="$(jq -n --arg t "$title" --arg b "$body" --argjson l "$label_ids" \
  '{title: $t, body: $b, labels: $l}')"

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

code="$(auth | curl -s --config - \
  -o "$out" -w '%{http_code}' \
  -X POST -H 'Content-Type: application/json' \
  -d "$payload" \
  "$api/repos/$repo/issues")"

if [ "$code" = 201 ]; then
  jq -r '"created #\(.number) [\(.state)]  \(.html_url)"' "$out"
else
  msg="$(jq -r '.message // .' "$out" 2>/dev/null || cat "$out")"
  echo "cbissue: failed to create issue (HTTP $code): $msg" >&2
  exit 1
fi
