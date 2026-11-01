# shellcheck shell=bash
# Body of herdr-app-merge-settings (./herdr-app-wrap.nix, via writeShellApplication).
# Runs from the herdr-app wrapper before every launch when settings are
# declared: merges them into the app's settings.json, declared keys winning,
# everything else (zoom, Settings-screen edits) kept as the app left it.
#
#   herdr-app-merge-settings <declared.json>
#
# The app home is resolved the app's way: $HERDR_APP_HOME, else
# $XDG_CONFIG_HOME/herdr-app, else ~/.config/herdr-app (empty counts as unset).
# A settings.json that is a symlink (into a dotfiles checkout, say) is written
# through, as the app's own saves do, so the link survives. Nothing is written
# when the merge changes nothing: the app reloads settings.json live, and
# `herdr-app ls` & co. go through this wrapper too. Never blocks the launch.
set -euo pipefail

declared=${1:?usage: herdr-app-merge-settings <declared.json>}
home=${HERDR_APP_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr-app}
file=$(readlink -m "$home/settings.json")
mkdir -p "$(dirname "$file")"

if [ -e "$file" ]; then
  if ! merged=$(jq -s '.[0] * .[1]' "$file" "$declared" 2>/dev/null); then
    echo "herdr-app: $file isn't a JSON object; declared settings not applied" >&2
    exit 0
  fi
  [ "$(jq -S . <<<"$merged")" != "$(jq -S . "$file")" ] || exit 0
else
  merged=$(jq . "$declared")
fi

tmp="$file.tmp.$$"
printf '%s\n' "$merged" >"$tmp"
mv -f "$tmp" "$file"
