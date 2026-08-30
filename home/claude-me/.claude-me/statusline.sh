#!/usr/bin/env bash
set -euo pipefail

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

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

# Herdr tab-bar usage indicator (experiment): on the personal profile inside a
# Herdr pane, keep a watcher alive that shows weekly consumption in the tab
# bar while this tab is focused. Singleton per pane; dies with claude ($PPID).
# The weekly all-models % is free in the statusline JSON — publish it for the
# watcher so only the Fable-scoped % ever needs the (touchy) OAuth endpoint.
if [ "${HERDR_ENV:-}" = "1" ] && [ "$profile" = "me" ] && command -v bun >/dev/null 2>&1; then
  weekly=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  if [ -n "$weekly" ]; then
    printf '{"at":%s000,"all":%s}' "$(date +%s)" "$weekly" > /tmp/herdr-claude-weekly.json
  fi
  (nohup bun "$HOME/.claude/herdr-usage-watcher.ts" "$PPID" >/dev/null 2>&1 &) || true
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
printf '\033[34m%s\033[0m\033[32m%s\033[0m\033[33m%s\033[0m  \033[2m%s\033[0m   %s\033[0m \033[2m·\033[0m' \
  "$dir" "$branch" "$ctx_info" "$model" "$badge"