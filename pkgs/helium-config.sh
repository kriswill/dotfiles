# shellcheck shell=bash
# Body of the `helium-config` CLI. Loaded verbatim by pkgs/helium-config.nix
# via builtins.readFile into writeShellApplication (which prepends the shebang and
# the runtimeInputs PATH, and runs shellcheck at build time). No Nix interpolation
# lives here — keep it plain bash so it can be linted/run standalone.
#
# Snapshot files are stored ENCRYPTED at rest. Each allowlisted file is captured,
# jq-churn-filtered (for the JSON ones), then armored-age-encrypted to
# config/helium/<rel>.age. The repo (PUBLIC on GitHub) therefore holds only opaque
# ciphertext — no browsing PII (visited domains, the Google account identity in
# Local State, cookies, saved logins) leaks. Encryption needs only the PUBLIC age
# recipient, so `capture` runs unattended; decryption (restore/diff and capture's
# compare-skip) pulls the age identity from 1Password via `op read` into memory,
# never off nebula's unencrypted disk.
set -euo pipefail

prof="${HELIUM_PROFILE:-$HOME/.config/net.imput.helium}"
repo="${DOTFILES:-$HOME/src/dotfiles}"
snap="$repo/config/helium"

# Public age recipient (== keyring.age.nebula / .sops.yaml). Encrypting needs only
# this, so `capture` works without unlocking 1Password.
recipient="${HELIUM_AGE_RECIPIENT:-age1gduheq5k8trpxduq56qt3yy6g0mveshx4h06nshccejvv6yxp4vq77m3qf}"
# Decryption identity reference in 1Password (pulled via `op read` into memory).
# Override with HELIUM_AGE_OP_REF; empty disables the op route (no-colon ${VAR-…}
# so an explicit empty value really disables it instead of falling back).
age_op_ref="${HELIUM_AGE_OP_REF-op://Private/nebula sops-age key/vc55ix7uexvletq4awkmh26mg4}"

# Snapshot path for an allowlist relpath — always the encrypted (.age) form.
enc_path() { printf '%s/%s.age\n' "$snap" "$1"; }

# Allowlist: "relpath-under-profile|transform". transform ∈ raw|prefs|localstate.
# Every entry is stored encrypted; raw = byte-copy (also used for the binary SQLite
# Cookies/Login Data), prefs/localstate = the per-file jq churn filters.
files=(
  "Default/Bookmarks|raw"
  "Default/Bookmarks.bak|raw"
  "Default/Preferences|prefs"
  "Local State|localstate"
  "Default/Cookies|raw"
  "Default/Login Data|raw"
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

# Age identity, resolved ONCE per invocation and cached in memory (one `op read`,
# so at most one 1Password prompt even across many files). Resolution order:
# explicit env override -> 1Password (op read) -> on-disk key (transitional, slated
# for removal). The key is never written to disk: decrypt feeds it to age over a
# /dev/fd pipe via the `printf` shell builtin (never on disk, never in argv).
_ident=""
_ident_tried=0
load_identity() {
  [ "$_ident_tried" = 1 ] && { [ -n "$_ident" ]; return; }
  _ident_tried=1
  if [ -n "${HELIUM_AGE_IDENTITY:-}" ] && [ -f "${HELIUM_AGE_IDENTITY}" ]; then
    _ident="$(cat "${HELIUM_AGE_IDENTITY}")"; return 0
  fi
  if [ -n "$age_op_ref" ] && command -v op >/dev/null 2>&1; then
    if _ident="$(op read "$age_op_ref" 2>/dev/null)" && [ -n "$_ident" ]; then
      return 0
    fi
  fi
  if [ -f "$HOME/.config/sops/age/keys.txt" ]; then
    _ident="$(cat "$HOME/.config/sops/age/keys.txt")"; return 0
  fi
  return 1
}

# decrypt <ciphertext-path> -> plaintext on stdout. Nonzero if no identity resolved.
decrypt() {
  if ! load_identity; then
    echo "helium-config: no age identity — unlock 1Password, or set HELIUM_AGE_IDENTITY/HELIUM_AGE_OP_REF" >&2
    return 1
  fi
  age -d -i <(printf '%s\n' "$_ident") "$1"
}

case "${1:-}" in
  capture)
    tmpfiles=()
    trap 'rm -f "${tmpfiles[@]}"' EXIT        # shred TMPDIR plaintext even on set -e abort
    if pgrep -x helium >/dev/null 2>&1; then
      echo "note: Helium is running — Cookies/Login Data (SQLite) may capture mid-write; quit it for a consistent snapshot." >&2
    fi
    present=0; wrote=0; skipped=0
    for entry in "${files[@]}"; do
      rel="${entry%|*}"; xf="${entry#*|}"
      src="$prof/$rel"; dst="$(enc_path "$rel")"
      [ -f "$src" ] || { echo "skip (absent): $rel" >&2; continue; }
      present=$((present + 1))
      mkdir -p "$(dirname "$dst")"
      # filtered plaintext -> TMPDIR scratch (NEVER inside the repo tree)
      new_plain="$(mktemp "${TMPDIR:-/tmp}/helium-cap.XXXXXX")"; tmpfiles+=("$new_plain")
      if ! apply "$xf" "$src" > "$new_plain"; then
        echo "ERROR: $rel is not valid JSON" >&2; exit 1
      fi
      # compare-skip: age's fresh nonce makes ciphertext nondeterministic, so only
      # re-encrypt when the decrypted plaintext actually changed (keeps git stable).
      # If we can't decrypt the existing snapshot to compare (e.g. 1Password locked),
      # DON'T re-encrypt — a fresh nonce over identical content would churn git on
      # every unattended run. Leave it untouched and tell the user to unlock + re-run.
      if [ -f "$dst" ]; then
        old_plain="$(mktemp "${TMPDIR:-/tmp}/helium-old.XXXXXX")"; tmpfiles+=("$old_plain")
        if decrypt "$dst" > "$old_plain" 2>/dev/null; then
          if cmp -s "$new_plain" "$old_plain"; then echo "unchanged: $rel" >&2; continue; fi
        else
          echo "warn: cannot decrypt existing $rel.age to compare — left as-is (unlock 1Password to update)" >&2
          skipped=$((skipped + 1)); continue
        fi
      fi
      enc_tmp="$dst.tmp.$$"
      if ! age -a -r "$recipient" -o "$enc_tmp" "$new_plain"; then
        rm -f "$enc_tmp"; echo "ERROR: age encryption failed for $rel" >&2; exit 1
      fi
      mv -f "$enc_tmp" "$dst"
      chmod 644 "$dst"            # repo copy; live perms re-hardened on restore
      echo "captured: $rel"
      wrote=$((wrote + 1))
    done
    if [ "$present" = 0 ]; then
      echo "nothing captured (no allowlisted files present)" >&2
    elif [ "$wrote" = 0 ] && [ "$skipped" = 0 ]; then
      echo "all $present file(s) already in sync — nothing to commit" >&2
    fi
    if [ "$skipped" != 0 ]; then
      echo "note: $skipped file(s) left unchanged (couldn't decrypt to compare) — unlock 1Password and re-run to update them" >&2
    fi
    echo "review: git -C $repo diff -- config/helium   # armored .age ciphertext"
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
      src="$(enc_path "$rel")"; dst="$prof/$rel"
      [ -f "$src" ] || continue
      mkdir -p "$(dirname "$dst")"
      [ -f "$dst" ] && cp -f "$dst" "$dst.bak"   # same-dir backup of live
      tmp="$(dirname "$dst")/.$(basename "$dst").new.$$"
      if ! decrypt "$src" > "$tmp"; then
        rm -f "$tmp"; echo "ERROR: cannot decrypt $rel.age" >&2; exit 1
      fi
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
    dec="$(mktemp "${TMPDIR:-/tmp}/helium-diff.XXXXXX")"
    trap 'rm -f "$dec"' EXIT
    for entry in "${files[@]}"; do
      rel="${entry%|*}"; xf="${entry#*|}"
      src="$(enc_path "$rel")"; live="$prof/$rel"
      [ -f "$src" ] || continue
      [ -f "$live" ] || { echo "## $rel: live missing"; rc=1; continue; }
      # Decrypt to a real file first so a decrypt failure is detectable — inside a
      # <(…) process substitution age's exit status is lost and diff would report
      # the whole live file as differing, masking "couldn't decrypt" as "out of sync".
      if ! decrypt "$src" > "$dec" 2>/dev/null; then
        echo "## $rel: cannot decrypt snapshot — unlock 1Password (or set HELIUM_AGE_*)" >&2; rc=1; continue
      fi
      # $dec is the already-filtered plaintext; apply() runs only on the live side.
      # Do NOT re-filter the snapshot (it was apply()-ed at capture).
      if ! diff -u "$dec" <(apply "$xf" "$live"); then rc=1; fi
    done
    if [ "$rc" = 0 ]; then echo "(in sync)"; fi
    exit "$rc"                  # explicit (hardens the old implicit exit-code footgun)
    ;;
  *)
    echo "usage: helium-config {capture|restore|diff}" >&2
    echo "  capture  live -> repo snapshot (encrypted config/helium/*.age)" >&2
    echo "  restore  repo snapshot -> live (decrypt, atomic, 0600; quit Helium first)" >&2
    echo "  diff     show snapshot (decrypted) vs filtered live" >&2
    exit 2
    ;;
esac
