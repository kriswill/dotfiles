# shellcheck shell=bash
# Body of herdr-update-check (./herdr-update-check.nix, via writeShellApplication).
# Linux and macOS. Reports two kinds of staleness, for each of our herdrs:
#
#   upstream  a newer release than ours:
#             - the herdr TUI fork (herdr-cli): GitHub releases/latest for
#               herdrdev/herdr (skips the preview-* prereleases) is past the
#               base of our vX.Y.Z-custom tag — rebase `custom` onto it, tag
#               it vA.B.C-custom, repoint the herdr-cli input in
#               flakes/herdr/flake.nix;
#             - herdr-core / herdr-app: releases.herdr.dev/{core,app}/latest.json
#               (the manifests the installers and the app's own updater read)
#               — refresh sources.json with update.ts.
#   running   a process older than the installed build: a rebuild swaps the
#             store path, not the running process. The herdr server needs
#             `herdr server stop` and a fresh `herdr`; `hc server restart`
#             moves the core over (terminals keep running); a Herdr window
#             needs reopening.
#
#   herdr-update-check            print what's pending; exit 10 if anything is
#   herdr-update-check --notify   also raise a desktop notification; exit 0
#
# Ours: $HERDR_CLI_VERSION / $HERDR_CORE_VERSION / $HERDR_APP_VERSION (the
# modules pass the configured packages'), else the versions this flake pins
# ($HERDR_*_PINNED, set by the package). Set one to the empty string to skip
# that product.
#
# --notify on Linux uses notify-send with a button per release (its release
# page or changelog), after waiting for a notification daemon: under a
# lingering user manager a missed timer fires at boot, before login. It blocks
# until the notification is answered (12h at most), so run it as a Type=exec
# unit, not oneshot. On macOS it posts a plain notification (osascript has no
# buttons).
set -euo pipefail

notify=0
case "${1:-}" in
--notify) notify=1 ;;
"") ;;
*)
  echo "usage: herdr-update-check [--notify]" >&2
  exit 2
  ;;
esac

cli=${HERDR_CLI_VERSION-${HERDR_CLI_PINNED:-}}
core=${HERDR_CORE_VERSION-${HERDR_CORE_PINNED:-}}
app=${HERDR_APP_VERSION-${HERDR_APP_PINNED:-}}

semver='^[0-9]+\.[0-9]+\.[0-9]+$'
newer() { # newer <ours> <theirs>: theirs is a strictly later version
  [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" = "$2" ]
}

lines=()
urls=()   # parallel to lines: what that item's button opens ('' = no button)
labels=() # ... and the button's label
add() {   # add <url> <label> <line>
  urls+=("$1")
  labels+=("$2")
  lines+=("$3")
}

# --- upstream: network hiccups or odd answers stay silent until next run
if [ -n "$cli" ]; then
  tag=$(curl -fsSL --max-time 30 -H 'Accept: application/vnd.github+json' \
    https://api.github.com/repos/herdrdev/herdr/releases/latest |
    jq -r '.tag_name // empty') || true
  if [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && newer "$cli" "${tag#v}"; then
    add "https://github.com/herdrdev/herdr/releases/tag/$tag" "herdr $tag release" \
      "herdr $tag released (our fork: v$cli-custom): rebase custom onto $tag, tag $tag-custom, repoint the herdr-cli input"
  fi
fi
latest() { # latest core|app
  curl -fsSL --max-time 30 "https://releases.herdr.dev/$1/latest.json" | jq -r '.version // empty' || true
}
bump=0
if [ -n "$core" ]; then
  v=$(latest core)
  if [[ "$v" =~ $semver ]] && newer "$core" "$v"; then
    add "https://github.com/herdrdev/herdr-core/blob/v$v/CHANGELOG.md" "herdr-core $v changes" \
      "herdr-core $v released (ours: $core)"
    bump=1
  fi
fi
if [ -n "$app" ]; then
  v=$(latest app)
  if [[ "$v" =~ $semver ]] && newer "$app" "$v"; then
    add "https://github.com/herdrdev/herdr-app/blob/v$v/CHANGELOG.md" "herdr-app $v changes" \
      "herdr-app $v released (ours: $app)"
    bump=1
  fi
fi

# --- running: versions read off the store path of each process's executable:
#   <store>/herdr-X.Y.Z/bin/herdr                        `herdr server`, the TUI's server
#   <store>/herdr-core-X.Y.Z/bin/herdr-core              `herdr-core serve`, the core
#                                                        (holders drain on their own)
#   <store>/herdr-app[-unwrapped]-X.Y.Z/…/herdr-app      a window (no arguments)
# On Linux argv[0] is that path. On macOS a process started through a symlink
# (`hc` on PATH, /etc/herdr-core/hc, the module's core pin) names the link in
# its argv, so lsof names the executable instead. A window opened from Finder
# runs nix-darwin's copy under "/Applications/Nix Apps", which carries no
# version: only a window opened as bin/herdr-app from a shell can be judged.
# Builds from anywhere else carry no version and are left alone.
darwin=0
[ "$(uname -s)" = Darwin ] && darwin=1
exe_of() { # exe_of <pid> <argv0>: the executable's path
  if [ "$darwin" = 1 ]; then
    /usr/sbin/lsof -a -p "$1" -d txt -Fn 2>/dev/null | sed -n 's/^n//p' | head -1
  else
    printf '%s\n' "$2"
  fi
}
# pid, then argv, one process per line
procs=$(ps -ww -u "$(id -u)" -o pid=,args= 2>/dev/null || true)
stale() { # stale <installed> <ERE on the argv> <ERE on the executable, capturing the version> <line, with %s for it>
  local pid args exe v
  while read -r pid args; do
    [ -n "$pid" ] || continue
    exe=$(exe_of "$pid" "${args%% *}")
    v=$(sed -nE "s#$3#\1#p" <<<"$exe")
    if [ -n "$v" ] && newer "$v" "$1"; then
      # shellcheck disable=SC2059 # the format is ours
      add "" "" "$(printf "$4" "$v")"
    fi
  done < <(grep -E "^ *[0-9]+ $2\$" <<<"$procs" | sort -u)
}
store='^/nix/store/[a-z0-9]{32}-'
if [ -n "$cli" ]; then
  stale "$cli" '[^ ]*/herdr server' "${store}herdr-([0-9]+\.[0-9]+\.[0-9]+)/bin/herdr\$" \
    "the running herdr server is %s, installed $cli: 'herdr server stop', then start herdr again"
fi
if [ -n "$core" ]; then
  stale "$core" '[^ ]*/(herdr-core|hc) serve( .*)?' "${store}herdr-core-([0-9]+\.[0-9]+\.[0-9]+)/bin/(herdr-core|hc)\$" \
    "the running herdr-core is %s, installed $core: run 'hc server restart' (terminals keep running)"
fi
if [ -n "$app" ]; then
  stale "$app" '[^ ]*/(herdr-app|Herdr)' "${store}herdr-app(-unwrapped)?-([0-9]+\.[0-9]+\.[0-9]+)/.*\$" \
    "an open Herdr window runs %s, installed $app: quit and reopen it (terminals keep running)"
fi

[ "${#lines[@]}" -gt 0 ] || exit 0
if [ "$bump" = 1 ]; then
  add "" "" "herdr-core/herdr-app: refresh flakes/herdr/sources.json (bun update.ts), then rebuild"
fi
printf '%s\n' "${lines[@]}"
[ "$notify" = 1 ] || exit 10

summary="herdr: updates pending"
body=$(printf '%s\n' "${lines[@]}")
if [ "$(uname -s)" = Darwin ]; then
  # osascript string literals: escape backslashes and double quotes.
  esc() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' <<<"$1"; }
  /usr/bin/osascript -e "display notification \"$(esc "$body")\" with title \"$(esc "$summary")\"" || true
  exit 0
fi

for _ in $(seq 720); do
  busctl --user status org.freedesktop.Notifications >/dev/null 2>&1 && break
  sleep 60
done
buttons=()
for i in "${!urls[@]}"; do
  if [ -n "${urls[$i]}" ]; then buttons+=(-A "$i=${labels[$i]}"); fi
done
action=$(timeout 12h notify-send -u critical "${buttons[@]}" "$summary" "$body" || true)
if [[ "$action" =~ ^[0-9]+$ ]] && [ -n "${urls[$action]:-}" ]; then
  xdg-open "${urls[$action]}"
fi
