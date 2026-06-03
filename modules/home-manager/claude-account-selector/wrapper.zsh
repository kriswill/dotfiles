# ---------------------------------------------------------------------------
# claude — profile-aware wrapper around the Claude Code CLI
#   claude [me|work] [args…]     launch; me/work force the profile for this run
#   claude                       launch; profile = longest-prefix match of $PWD
#   claude pin <me|work> [path]  remember path-prefix → profile (default: cwd)
#   claude unpin [path]          forget a pinned prefix (default: cwd)
#   claude which [path]          show which profile a path resolves to
#   claude pins                  list all rules (built-in + pinned)
# Built-in default: under ~/src/perforce → work; everything else → me.
# Pins: $XDG_STATE_HOME/claude/profile-map.tsv (mutable, NOT nix-managed).
# Bypass the wrapper entirely with:  command claude …
# NOTE: never name a local `path` here — it is zsh's special $PATH array.
# ---------------------------------------------------------------------------

_ccw_builtin_rules() { printf '%s\t%s\n' "$HOME/src/perforce" work; }
_ccw_map_file()      { printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/claude/profile-map.tsv"; }

_ccw_abspath() {                       # absolutize + normalize (default: cwd)
  emulate -L zsh
  local p="${1:-$PWD}"
  [[ "$p" != /* ]] && p="$PWD/$p"
  print -r -- "${p:A}"
}

_ccw_resolve() {                       # $1 = abs path → winning profile ("" if none)
  emulate -L zsh
  local target="$1" prefix profile best_len=-1 best=""
  local mapf; mapf="$(_ccw_map_file)"
  while IFS=$'\t' read -r prefix profile; do
    [[ -z "$prefix" || "$prefix" == \#* ]] && continue
    prefix="${prefix:A}"
    [[ "$target" == "$prefix" || "$target" == "$prefix"/* ]] || continue
    (( ${#prefix} >= best_len )) && { best_len=${#prefix}; best="$profile"; }   # user pins (read last) win ties
  done < <( _ccw_builtin_rules; [[ -r "$mapf" ]] && cat "$mapf" )
  print -r -- "$best"
}

_ccw_token() { security find-generic-password -s "claude-token-$1" -a "$USER" -w 2>/dev/null; }

claude() {
  emulate -L zsh
  local mapf tgt profile tok verb="$1"

  case "$verb" in
    pin)
      shift; profile="$1"; shift
      [[ "$profile" == me || "$profile" == work ]] || { print -u2 "claude pin: profile must be me|work"; return 2; }
      tgt="$(_ccw_abspath "${1:-$PWD}")"; mapf="$(_ccw_map_file)"; mkdir -p "${mapf:h}"
      [[ -f "$mapf" ]] && { awk -F'\t' -v p="$tgt" '$1!=p' "$mapf" > "$mapf.tmp" && mv "$mapf.tmp" "$mapf"; }
      printf '%s\t%s\n' "$tgt" "$profile" >> "$mapf"
      print -r -- "pinned   $tgt → $profile"; return 0 ;;
    unpin)
      shift; tgt="$(_ccw_abspath "${1:-$PWD}")"; mapf="$(_ccw_map_file)"
      [[ -f "$mapf" ]] || { print -r -- "no pins"; return 0; }
      if awk -F'\t' -v p="$tgt" '$1==p{f=1} END{exit !f}' "$mapf"; then
        awk -F'\t' -v p="$tgt" '$1!=p' "$mapf" > "$mapf.tmp" && mv "$mapf.tmp" "$mapf"
        print -r -- "unpinned $tgt"
      else print -r -- "no pin at $tgt"; fi
      return 0 ;;
    which)
      shift; tgt="$(_ccw_abspath "${1:-$PWD}")"; profile="$(_ccw_resolve "$tgt")"; profile="${profile:-me}"
      print -r -- "$tgt → $profile   (CLAUDE_CONFIG_DIR=$HOME/.claude-$profile)"; return 0 ;;
    pins)
      print -r -- "# built-in"; _ccw_builtin_rules
      mapf="$(_ccw_map_file)"; print -r -- "# pinned ($mapf)"; [[ -r "$mapf" ]] && cat "$mapf"
      return 0 ;;
  esac

  # launch
  # An explicit CLAUDE_CONFIG_DIR from the caller wins — pass through untouched, so
  # e.g. `CLAUDE_CONFIG_DIR=~/.claude-work claude setup-token` targets that dir.
  if [[ -n "$CLAUDE_CONFIG_DIR" ]]; then
    command claude "$@"; return
  fi
  case "$verb" in
    me|work) profile="$verb"; shift ;;
    *)       profile="$(_ccw_resolve "$(_ccw_abspath "$PWD")")" ;;
  esac
  profile="${profile:-me}"
  tok="$(_ccw_token "$profile")"
  if [[ -n "$tok" ]]; then
    CLAUDE_CONFIG_DIR="$HOME/.claude-$profile" CLAUDE_CODE_OAUTH_TOKEN="$tok" command claude "$@"
  else
    CLAUDE_CONFIG_DIR="$HOME/.claude-$profile" command claude "$@"
  fi
}
