# shellcheck shell=bash
# Body of the `helium-config` CLI. Loaded verbatim by packages/helium-config.nix
# via builtins.readFile into writeShellApplication (which prepends the shebang and
# the runtimeInputs PATH, and runs shellcheck at build time). No Nix interpolation
# lives here — keep it plain bash so it can be linted/run standalone.
set -euo pipefail

prof="${HELIUM_PROFILE:-$HOME/.config/net.imput.helium}"
repo="${DOTFILES:-$HOME/src/dotfiles}"
snap="$repo/config/helium"

# Allowlist: "relpath-under-profile|transform". transform ∈ raw|prefs|localstate.
files=(
  "Default/Bookmarks|raw"
  "Default/Bookmarks.bak|raw"
  "Default/Preferences|prefs"
  "Local State|localstate"
)

# Drop volatile/footgun keys; extend as churn is observed. del() on an absent
# path is a no-op in jq, so these are safe even if a key isn't present.
prefs_filter='del(.profile.exit_type, .profile.last_engagement_time, .profile.last_active_time, .browser.window_placement, .session, .sessions, .extensions.last_chrome_version, .ntp.num_personal_suggestions)'
localstate_filter='del(.user_experience_metrics, .variations_crash_streak, .variations_failed_to_fetch_seed_streak, .variations_seed_date, .session_id_generator_last_value, .uninstall_metrics, .legacy)'

# apply <transform> <infile> -> stdout. Filtered outputs are key-sorted (-S)
# so Chromium re-ordering keys doesn't show up as spurious diffs.
apply() {
  case "$1" in
    raw)        cat "$2" ;;
    prefs)      jq -S "$prefs_filter" "$2" ;;
    localstate) jq -S "$localstate_filter" "$2" ;;
    *)          echo "unknown transform: $1" >&2; return 1 ;;
  esac
}

case "${1:-}" in
  capture)
    any=0
    for entry in "${files[@]}"; do
      rel="${entry%|*}"; xf="${entry#*|}"
      src="$prof/$rel"; dst="$snap/$rel"
      [ -f "$src" ] || { echo "skip (absent): $rel" >&2; continue; }
      mkdir -p "$(dirname "$dst")"
      if ! apply "$xf" "$src" > "$dst.tmp.$$"; then
        rm -f "$dst.tmp.$$"; echo "ERROR: $rel is not valid JSON" >&2; exit 1
      fi
      mv -f "$dst.tmp.$$" "$dst"
      chmod 644 "$dst"            # repo copy; live perms re-hardened on restore
      echo "captured: $rel"
      any=1
    done
    [ "$any" = 1 ] || echo "nothing captured (no allowlisted files present)" >&2
    echo "review: git -C $repo diff -- config/helium"
    ;;
  restore)
    # A live save racing this restore is last-writer-wins. Refuse while Helium
    # runs unless FORCE=1. Helium reads these only at startup (no reload IPC),
    # so this is for a quit browser / fresh machine.
    if pgrep -x helium >/dev/null 2>&1 && [ "${FORCE:-}" != 1 ]; then
      echo "helium is running — quit it first, or re-run with FORCE=1." >&2
      exit 1
    fi
    any=0
    for entry in "${files[@]}"; do
      rel="${entry%|*}"
      src="$snap/$rel"; dst="$prof/$rel"
      [ -f "$src" ] || continue
      mkdir -p "$(dirname "$dst")"
      [ -f "$dst" ] && cp -f "$dst" "$dst.bak"   # same-dir backup of live
      tmp="$(dirname "$dst")/.$(basename "$dst").new.$$"
      cp -f "$src" "$tmp"
      chmod 600 "$tmp"                            # git records only the exec bit
      mv -f "$tmp" "$dst"                         # atomic rename (Chromium's pattern)
      echo "restored: $rel"
      any=1
    done
    [ "$any" = 1 ] || { echo "no snapshot files at $snap" >&2; exit 1; }
    echo "restored (atomic, 0600). Helium loads these at next launch."
    ;;
  diff)
    rc=0
    for entry in "${files[@]}"; do
      rel="${entry%|*}"; xf="${entry#*|}"
      src="$snap/$rel"; live="$prof/$rel"
      [ -f "$src" ] || continue
      [ -f "$live" ] || { echo "## $rel: live missing"; rc=1; continue; }
      if ! diff -u "$src" <(apply "$xf" "$live"); then rc=1; fi
    done
    [ "$rc" = 0 ] && echo "(in sync)"
    ;;
  *)
    echo "usage: helium-config {capture|restore|diff}" >&2
    echo "  capture  live -> repo snapshot (config/helium/...)" >&2
    echo "  restore  repo snapshot -> live (atomic, 0600; quit Helium first)" >&2
    echo "  diff     show snapshot vs filtered live" >&2
    exit 2
    ;;
esac
