#!/usr/bin/env bash
set -euo pipefail

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
session_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Directory: show basename like starship default
dir=$(basename "$cwd")

# Git branch (skip optional locks)
branch=""
if git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  branch=" $git_branch"
fi

# Usage bars — dotbar braille bars (green→red as they fill) with dotbar's own
# dim NN% suffix, each prefixed with a dim label. Falls back to plain text
# without dotbar. ctx = used context window, ses = 5-hour session rate limit.
sep=' \033[2m•\033[0m ' # small dim bullet pill between components
bar() { # $1=label $2=used% $3=muted label/% color (R;G;B)
  if command -v dotbar >/dev/null 2>&1; then
    # Recolor dotbar's dim NN% suffix to match the label.
    out=$(dotbar --dense "$2" | sed "s/\x1b\[2m/\x1b[38;2;$3m/")
    printf "${sep}"'\033[38;2;%sm%s\033[0m %s' "$3" "$1" "$out"
  else
    printf "${sep}"'\033[38;2;%sm%s %s%%\033[0m' "$3" "$1" "$2"
  fi
}
ctx_info=""
[ -n "$remaining" ] && ctx_info=$(bar ctx $((100 - ${remaining%.*})) "69;133;136")   # muted blue
ses_info=""
[ -n "$session_used" ] && ses_info=$(bar ses "${session_used%.*}" "177;98;134")     # muted purple

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
# "default" counts as personal: nebula's single-account setup has no
# account-selector, so CLAUDE_CONFIG_DIR is unset there ("me" is macs-only).
if [ "${HERDR_ENV:-}" = "1" ] && { [ "$profile" = "me" ] || [ "$profile" = "default" ]; } && command -v bun >/dev/null 2>&1; then
  weekly=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
  if [ -n "$weekly" ]; then
    printf '{"at":%s000,"all":%s}' "$(date +%s)" "$weekly" > /tmp/herdr-claude-weekly.json
  fi
  (nohup bun "$HOME/.claude/herdr-usage-watcher.ts" "$PPID" >/dev/null 2>&1 &) || true
fi

# Effort level next to the model, e.g. "Fable 5 (medium)".
effort_info=""
[ -n "$effort" ] && effort_info=" (${effort})"

# Per-profile boxed badge (bold near-black on truecolor bg). The default
# profile gets no badge — it's the uninteresting case. Warm = work, cool = me.
badge=""
if [ "$profile" != "default" ]; then
  case "$profile" in
    work) badge_bg="254;128;25"  ;;   # amber
    me)   badge_bg="131;165;152" ;;   # teal
    *)    badge_bg="146;131;116" ;;   # grey fallback
  esac
  label=$(printf '%s' "$profile" | tr '[:lower:]' '[:upper:]')
  # Trailing dim dot after the badge: Claude Code's renderer pads the
  # statusline row to full width by extending the LAST styled span, so a line
  # ending in a background-colored badge bleeds that background across the
  # padding (trailing whitespace, even NBSP, gets trimmed first). End on a
  # visible default-bg span.
  badge=$(printf "${sep}"'\033[1;38;2;29;32;33;48;2;%sm %s \033[0m \033[2m·\033[0m' "$badge_bg" "$label")
fi

# Model in Claude brand tangerine (#D97757); effort stays dim.
printf '\033[34m%s\033[0m\033[32m%s\033[0m%s%s'"${sep}"'\033[38;2;217;119;87m%s\033[0m\033[2m%s\033[0m%s' \
  "$dir" "$branch" "$ctx_info" "$ses_info" "$model" "$effort_info" "$badge"