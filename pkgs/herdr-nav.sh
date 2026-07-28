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
# Exit-status contract: every path exits 0 except a usage error (2). This runs
# on a keypress, and a broken socket must not spew errors into the user's
# session — but it also lets config.toml chain
# `herdr-nav left || herdr pane focus …` so the fallback fires ONLY when
# herdr-nav is missing from PATH (127 from the spawning shell), never when
# herdr-nav ran and deliberately forwarded the chord to vim. Keep it that way.
#
# The pane is always resolved through the server (`--current`, then the id that
# comes back). $HERDR_PANE_ID is never read: herdr normally spawns this without
# pane env vars at all, and a nested or oddly-launched server leaks the *outer*
# session's stale ids through instead.

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

# A held key fires several detached copies of this script, each resolving the
# focused pane independently — so without serialising, two presses can read the
# same pre-move pane and the walk loses a step. Hold a lock across
# resolve-and-act so press N sees where press N-1 left focus. mkdir is the
# portable test-and-set; flock(1) does not exist on macOS.
lock="${TMPDIR:-/tmp}/herdr-nav-$(id -u).lock"
held=""
trap '[ -n "$held" ] && rmdir "$lock" 2>/dev/null || true' EXIT

waited=0
while [ "$waited" -lt 30 ]; do
  if mkdir "$lock" 2>/dev/null; then
    held=1
    break
  fi
  sleep 0.01
  waited=$((waited + 1))
done
if [ -z "$held" ]; then
  # 300ms is far longer than two socket round-trips, so the holder is gone and
  # left its directory behind. Clear it so the next press is fast again, and
  # carry on unlocked: dropping a keypress is worse than a rare double move.
  rmdir "$lock" 2>/dev/null || true
fi

# One socket round-trip gives us both the focused pane's id and everything
# running in its foreground process tree. `--current` resolves server-side for
# process-info (and for focus/layout), which matters because herdr spawns us
# without pane env vars.
info=$(herdr pane process-info --current 2>/dev/null) || exit 0
[ -n "$info" ] || exit 0

pane=$(printf '%s' "$info" | jq -r '.result.process_info.pane_id // empty') || exit 0
[ -n "$pane" ] || exit 0

# The same set tmux.conf matches with `ps`: vim/nvim/view/fzf in the pane's
# foreground process tree (so `git commit` opening $EDITOR counts). Matched on
# argv0 and argv[0]'s basename — `name` is the kernel's comm, truncated to 15
# characters, so it is a last resort for entries that carry no argv.
#
# Daemon invocations of those same programs are excluded, per program, because
# the flag that means "not a UI" differs: `--headless`/`--embed` for vim (LSP
# and formatter hosts, GUI clients) and `--listen` for fzf (driven as a server
# by another tool). Forwarding the chord to one types a stray backspace into
# whatever IS in the pane. The exclusions are deliberately NOT pooled: `nvim
# --listen /tmp/sock` is an ordinary interactive editor, and a blanket
# `--listen` test would stop forwarding to it.
#
# Residual gap, documented rather than papered over: herdr's payload carries no
# parent pid, so the process tree cannot be rebuilt, and an interactive vim
# running as a *background* child of the foreground job still matches. tmux's
# ps-based is_vim has the same shape of gap (it additionally filters process
# state, `^[^TXZ ]+`, which herdr does not expose).
is_vim=$(printf '%s' "$info" | jq -r '
  def base: sub(".*/"; "");
  def names: [((.argv[0]? // "") | base), ((.argv0 // "") | base), (.name // "")];
  def flags: [.argv[]?];
  [ .result.process_info.foreground_processes[]?
    | ((names | any(test("^g?(view|n?vim?x?)(diff)?$")))
       and (flags | any(. == "--headless" or . == "--embed") | not))
      or
      ((names | any(test("^fzf$")))
       and (flags | any(. == "--listen") | not))
  ]
  | any
') || exit 0

if [ "$is_vim" = "true" ]; then
  herdr pane send-keys "$pane" "$key" >/dev/null 2>&1 || true
else
  # Act on the id we just inspected rather than resolving --current a second
  # time: the check and the move have to be about the same pane.
  herdr pane focus --direction "$1" --pane "$pane" >/dev/null 2>&1 || true
fi

exit 0
