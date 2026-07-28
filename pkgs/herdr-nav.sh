# herdr-nav — vim-aware pane navigation for herdr.
#
#   usage: herdr-nav <left|down|up|right>
#
# Bound to ctrl+h/j/k/l in home/herdr/.config/herdr/config.toml as a
# [[keys.command]] shell command. It is the herdr equivalent of the classic
# tmux `is_vim` + `if-shell` dance: if the focused pane is running vim/nvim,
# forward the chord to it (nvim moves between its own splits, and hands the
# motion back via `herdr pane focus` once it's against the edge — see
# home/nvim/.config/nvim/lua/config/multiplexer.lua). Otherwise move herdr's
# pane focus directly.
#
# Every failure path exits 0 without doing anything: this runs on a keypress,
# and a broken socket should not spew errors into the user's session.

case "${1:-}" in
  left) key="ctrl+h" ;;
  down) key="ctrl+j" ;;
  up) key="ctrl+k" ;;
  right) key="ctrl+l" ;;
  *)
    echo "usage: herdr-nav <left|down|up|right>" >&2
    exit 2
    ;;
esac

# One socket round-trip gives us both the focused pane's id and everything
# running in its foreground process tree. `--current` resolves through the
# server, so this works even though herdr spawns us without pane env vars.
info=$(herdr pane process-info --current 2>/dev/null) || exit 0

pane=$(printf '%s' "$info" | sed -n 's/.*"pane_id":"\([^"]*\)".*/\1/p')
[ -n "$pane" ] || exit 0

# The same set tmux.conf matches with `ps`: vim/nvim/view/fzf anywhere in the
# pane's foreground tree (covers `git commit` opening $EDITOR, etc.).
if printf '%s' "$info" | grep -qE '"(name|argv0)":"([^"]*/)?(g?(view|n?vim?x?)(diff)?|fzf)"'; then
  herdr pane send-keys "$pane" "$key" >/dev/null 2>&1 || true
else
  herdr pane focus --direction "$1" --pane "$pane" >/dev/null 2>&1 || true
fi
