#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
effort=$(echo "$input" | jq -r '.effort.level // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Model: drop the display name's trailing parenthetical — it states the context
# window size ("Opus 5 (1M context)"), which the context bar already covers in
# the form that actually changes. Put the reasoning effort in that slot instead.
model=${model%% (*}
[ -n "$effort" ] && model="$model ($effort)"

# Directory: show basename like starship default
dir=$(basename "$cwd")

# Git branch (skip optional locks)
branch=""
if git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  branch=" $git_branch"
fi

# Context usage — dotbar braille bar of *used* context (green→red as it fills),
# with dotbar's own dim NN% suffix. Falls back to plain text without dotbar.
ctx_info=""
if [ -n "$remaining" ]; then
  used=$((100 - ${remaining%.*}))
  if command -v dotbar >/dev/null 2>&1; then
    ctx_info=" $(dotbar --dense "$used")"
  else
    ctx_info=" ctx:${used}%"
  fi
fi

# Profile badge — dynamically resolved from the active Claude config dir.
# The `claude` wrapper exports CLAUDE_CONFIG_DIR=~/.claude-<profile> (me|work).
profile_dir=$(basename "${CLAUDE_CONFIG_DIR:-$HOME/.claude}")
case "$profile_dir" in
  .claude-*) profile="${profile_dir#.claude-}" ;;
  .claude)   profile="default" ;;
  *)         profile="$profile_dir" ;;
esac

# Credit spend — $used/$budget plus a dense dotbar of the percentage.
#
# Unlike the personal profile, the work profile's statusline JSON carries no
# rate_limits block, so the numbers come from claude.ai via the Claude desktop
# app's session cookie (see claude-usage-work.ts). That's a network call, so
# it never runs inline: read whatever the cache holds, and kick off a detached
# refresh when it has gone stale. Stale numbers beat a stalled statusline.
#
# Inside Herdr the tab bar shows this (one copy per window, always visible),
# so the statusline stays out of its way and only renders the segment when
# there is no tab bar to carry it. The refresh still runs either way — the
# watcher that feeds the tab bar reads this same cache and never fetches.
USAGE_CACHE=/tmp/claude-usage-work.json
USAGE_FRESH=60      # seconds a good reading stays authoritative
USAGE_RETRY=300     # seconds to wait after a failed refresh

spend_info=""
spend_pct=""
if [ "$profile" = "work" ]; then
  now=$(date +%s)
  cache=$(cat "$USAGE_CACHE" 2>/dev/null || echo '{}')
  read -r at failat spend_pct spend_used spend_limit <<<"$(
    echo "$cache" | jq -r '[((.at//0)/1000|floor), ((.failAt//0)/1000|floor),
                            (.pct//""), (.used//""), (.limit//"")] | @tsv' 2>/dev/null
  )" || true
  at=${at:-0}; failat=${failat:-0}
  if [ $((now - at)) -ge "$USAGE_FRESH" ] && [ $((now - failat)) -ge "$USAGE_RETRY" ] \
     && command -v bun >/dev/null 2>&1; then
    (nohup bun "$here/claude-usage-work.ts" >/dev/null 2>&1 &) || true
  fi
  if [ -n "$spend_pct" ] && [ "${HERDR_ENV:-}" != "1" ]; then
    if command -v dotbar >/dev/null 2>&1; then
      spend_info=$(printf '  \033[2m%s/%s\033[0m %s' "$spend_used" "$spend_limit" "$(dotbar --dense "$spend_pct")")
    else
      spend_info=$(printf '  \033[2m%s/%s %s%%\033[0m' "$spend_used" "$spend_limit" "$spend_pct")
    fi
  fi
fi

# Herdr tab-bar usage indicator: inside a Herdr pane, keep a watcher alive that
# publishes usage into the tab bar while this tab is focused. Singleton per
# pane; dies with claude ($PPID). The watcher reads the spend cache this
# statusline already refreshes, so it costs no extra API calls.
if [ "${HERDR_ENV:-}" = "1" ] && [ "$profile" = "work" ] && command -v bun >/dev/null 2>&1; then
  (nohup bun "$here/herdr-usage-watcher.ts" "$PPID" >/dev/null 2>&1 &) || true
fi

# Per-profile badge background (truecolor). Warm = work, cool = me.
case "$profile" in
  work) badge_bg="254;128;25"  ;;   # amber
  me)   badge_bg="131;165;152" ;;   # teal
  *)    badge_bg="146;131;116" ;;   # grey fallback
esac

# Boxed badge: bold near-black text on a filled colored background, padded.
label=$(printf '%s' "$profile" | tr '[:lower:]' '[:upper:]')
badge=$(printf '\033[1;38;2;29;32;33;48;2;%sm %s \033[0m' "$badge_bg" "$label")

# Trailing dim dot after the badge: Claude Code's renderer pads the statusline
# row to full width by extending the LAST styled span, so a line ending in a
# background-colored badge bleeds that background across the padding (trailing
# whitespace, even NBSP, gets trimmed first). End on a visible default-bg span.
printf '\033[34m%s\033[0m\033[32m%s\033[0m\033[33m%s\033[0m%s  \033[2m%s\033[0m   %s\033[0m \033[2m·\033[0m' \
  "$dir" "$branch" "$ctx_info" "$spend_info" "$model" "$badge"
