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

# Single source of truth for profiles (default + the valid set).
_CCW_DEFAULT_PROFILE=me
_CCW_VALID_PROFILES=(me work)
_ccw_is_profile() { emulate -L zsh; [[ -n "$1" ]] && (( ${_CCW_VALID_PROFILES[(Ie)$1]} )); }  # exact array membership

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
  local data; data="$(_ccw_builtin_rules)"
  [[ -r "$mapf" ]] && data+=$'\n'"$(<"$mapf")"          # native read — no cat fork
  while IFS=$'\t' read -r prefix profile; do
    prefix="${prefix%$'\r'}"; profile="${profile%$'\r'}"   # tolerate CRLF-edited maps
    [[ -z "$prefix" || "$prefix" == \#* ]] && continue
    _ccw_is_profile "$profile" || continue                 # ignore rules with an unknown profile
    prefix="${prefix:A}"
    [[ "$target" == "$prefix" || "$target" == "$prefix"/* ]] || continue
    (( ${#prefix} >= best_len )) && { best_len=${#prefix}; best="$profile"; }   # user pins (read last) win ties
  done <<< "$data"
  print -r -- "$best"
}

_ccw_token() { security find-generic-password -s "claude-token-$1" -a "$USER" -w 2>/dev/null; }

# Remove the row whose first (tab-separated) field equals $2 from map file $1.
# Uses ENVIRON (not `awk -v`) so backslashes in the path aren't escape-processed.
_ccw_map_remove() {
  emulate -L zsh
  [[ -f "$1" ]] || return 0
  CCW_KEY="$2" awk -F'\t' '$1 != ENVIRON["CCW_KEY"]' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

claude() {
  emulate -L zsh
  local mapf tgt profile tok verb="$1"

  case "$verb" in
    pin)
      shift; profile="$1"; shift
      _ccw_is_profile "$profile" || { print -u2 "claude pin: profile must be one of: ${_CCW_VALID_PROFILES[*]}"; return 2; }
      tgt="$(_ccw_abspath "$1")"
      [[ "$tgt" == *$'\t'* || "$tgt" == *$'\n'* ]] && { print -u2 "claude pin: path contains a tab/newline (unsupported)"; return 2; }
      mapf="$(_ccw_map_file)"; mkdir -p "${mapf:h}"
      _ccw_map_remove "$mapf" "$tgt"
      printf '%s\t%s\n' "$tgt" "$profile" >> "$mapf"
      print -r -- "pinned   $tgt → $profile"; return 0 ;;
    unpin)
      shift; tgt="$(_ccw_abspath "$1")"; mapf="$(_ccw_map_file)"
      [[ -f "$mapf" ]] || { print -r -- "no pins"; return 0; }
      if CCW_KEY="$tgt" awk -F'\t' '$1==ENVIRON["CCW_KEY"]{f=1} END{exit !f}' "$mapf"; then
        _ccw_map_remove "$mapf" "$tgt"
        print -r -- "unpinned $tgt"
      else print -r -- "no pin at $tgt"; fi
      return 0 ;;
    which)
      shift; tgt="$(_ccw_abspath "$1")"; profile="$(_ccw_resolve "$tgt")"; profile="${profile:-$_CCW_DEFAULT_PROFILE}"
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
    *)       profile="$(_ccw_resolve "$(_ccw_abspath)")" ;;
  esac
  profile="${profile:-$_CCW_DEFAULT_PROFILE}"
  # don't inject a token while (re)minting one or logging in — it would shadow the flow
  if [[ "$1" == setup-token || "$1" == login ]]; then tok=""; else tok="$(_ccw_token "$profile")"; fi
  if [[ -n "$tok" ]]; then
    CLAUDE_CONFIG_DIR="$HOME/.claude-$profile" CLAUDE_CODE_OAUTH_TOKEN="$tok" command claude "$@"
  else
    CLAUDE_CONFIG_DIR="$HOME/.claude-$profile" command claude "$@"
  fi
}
