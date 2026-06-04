#!/usr/bin/env zsh
# ---------------------------------------------------------------------------
# fix-config-dir-refs — rewrite stale "~/.claude/" references inside a copied
# profile config dir so they point at that profile's own CLAUDE_CONFIG_DIR.
#
# Why: the one-time setup seeds a profile with `cp -a ~/.claude ~/.claude-<p>`.
# Absolute paths baked into config files survive the copy verbatim, so e.g. a
# SessionStart hook registered as
#       "/Users/you/.claude/hooks/context-mode-cache-heal.mjs"
# still points at the ORIGINAL ~/.claude — which, under a profile, may not even
# exist, producing "No such file or directory" startup-hook errors. Plugins
# that gate re-registration on "is a hook already present?" never self-correct
# the stale base path, so it persists every session. This script rewrites such
# references (absolute and ~-form) to the target config dir.
#
# Scope: only the two behaviour-driving config files are scanned —
#       settings.json   settings.local.json
# These hold hook/statusLine command paths, the exact thing that breaks. Caches,
# transcripts, history and plugin dirs are left untouched (they legitimately
# record the old path as history, and plugins heal their own paths).
# .claude.json is deliberately NOT scanned: its `projects` map is keyed by real
# working directories, and one may legitimately live under ~/.claude (e.g. you
# once launched a session from ~/.claude/hooks) — rewriting those keys would
# corrupt project state. Fix any genuine ~/.claude/ path in .claude.json by hand.
# Only references with a trailing "/" are rewritten (e.g. ".claude/hooks/…"),
# so a sibling profile dir like ".claude-work/" is never matched.
#
# Defaults to a dry-run preview; pass --apply to write. Each rewritten file is
# JSON-validated and the change is discarded if it would corrupt the file.
#
# Usage:
#   fix-config-dir-refs [--from DIR] [--apply] [--no-backup] [TARGET_DIR]
#
#   TARGET_DIR     profile config dir to fix          (default: $CLAUDE_CONFIG_DIR)
#   --from DIR     original dir whose refs to rewrite  (default: ~/.claude)
#   --apply        write changes                       (default: preview only)
#   --no-backup    skip the <file>.bak-<ts> copy when applying
#   -h, --help     show this help
#
# Idempotent: a second run finds nothing to change. Standalone (no nix needed).
# NOTE: never name a variable `path` here — it is zsh's special $PATH array;
# shadowing it empties $PATH inside the function (mktemp/grep "not found").
# ---------------------------------------------------------------------------

_PROG=${0:t}

die()   { print -u2 -r -- "$_PROG: $*"; exit 1; }

usage() {
  print -r -- "Usage: $_PROG [--from DIR] [--apply] [--no-backup] [TARGET_DIR]

  TARGET_DIR     profile config dir to fix          (default: \$CLAUDE_CONFIG_DIR)
  --from DIR     original dir whose refs to rewrite  (default: ~/.claude)
  --apply        write changes                       (default: dry-run preview)
  --no-backup    skip the <file>.bak-<ts> copy when applying
  -h, --help     show this help"
}

_expand_tilde() {                       # leading ~ → $HOME (args aren't shell-expanded)
  emulate -L zsh
  local p="$1"
  [[ "$p" == "~" ]]   && p="$HOME"
  [[ "$p" == "~/"* ]] && p="$HOME/${p#\~/}"
  print -r -- "$p"
}

_validate_json() {                      # 0 = valid (or no validator available)
  emulate -L zsh
  if (( $+commands[node] )); then
    node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$1" 2>/dev/null
  elif (( $+commands[python3] )); then
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" 2>/dev/null
  else
    return 0                            # can't validate → assume the rewrite is fine
  fi
}

main() {
  emulate -L zsh
  set -u

  # ----- parse args --------------------------------------------------------
  local from="" target="" apply=0 backup=1
  while (( $# )); do
    case "$1" in
      --from)      from="${2:?--from needs a directory}"; shift 2 ;;
      --from=*)    from="${1#*=}"; shift ;;
      --apply)     apply=1; shift ;;
      --no-backup) backup=0; shift ;;
      -h|--help)   usage; exit 0 ;;
      --)          shift; break ;;
      -*)          usage; die "unknown option: $1" ;;
      *)           [[ -n "$target" ]] && die "unexpected extra argument: $1"; target="$1"; shift ;;
    esac
  done
  (( $# )) && { [[ -n "$target" ]] && die "unexpected extra argument: $1"; target="$1"; }

  # ----- resolve source / target dirs --------------------------------------
  : ${from:=$HOME/.claude}
  : ${target:=${CLAUDE_CONFIG_DIR:-}}
  [[ -n "$target" ]] || die "no TARGET_DIR given and \$CLAUDE_CONFIG_DIR is unset"

  from="$(_expand_tilde "$from")"
  target="$(_expand_tilde "$target")"

  # Absolutize/normalize WITHOUT resolving symlinks (:a, not :A) — the refs
  # Claude writes are homedir-based and unresolved, so we must match them as-is.
  local src_abs="${from:a}" dst_abs="${target:a}"

  [[ -d "$target" ]] || die "target config dir does not exist: $target"
  [[ "$src_abs" == "$dst_abs" ]] && die "target equals source ($src_abs) — nothing to do"

  # ----- build (from → to) replacement pairs -------------------------------
  # Anchored with a trailing "/" so sibling dirs (.claude-work/, .claude-me/)
  # and bare config-dir mentions are never matched.
  local -a pairs=("$src_abs/" "$dst_abs/")
  if [[ "$src_abs" == "$HOME/"* && "$dst_abs" == "$HOME/"* ]]; then
    pairs+=("~/${src_abs#$HOME/}/" "~/${dst_abs#$HOME/}/")   # also fix literal ~-form refs
  fi

  # ----- scan & rewrite ----------------------------------------------------
  local -a files=(settings.json settings.local.json)
  print -r -- "Fixing config-dir references in: $target"
  print -r -- "  rewriting refs to:            $src_abs"
  (( apply )) || print -r -- "  (dry-run — no files will be written; pass --apply to write)"
  print

  local f pth tmp fromstr tostr n i bak note
  local changed_total=0 would_change=0
  local -a notes

  for f in $files; do
    pth="$target/$f"
    [[ -f "$pth" ]] || continue

    tmp="$(mktemp "${TMPDIR:-/tmp}/ccfix.XXXXXX")" || die "mktemp failed"
    cp -- "$pth" "$tmp"

    notes=()
    for (( i=1; i<=${#pairs}; i+=2 )); do
      fromstr="${pairs[i]}"; tostr="${pairs[i+1]}"
      n=$(grep -oF -- "$fromstr" "$tmp" 2>/dev/null | wc -l | tr -d ' ')
      (( n > 0 )) || continue
      # \Q…\E quotes the search literally; the replacement is a plain var value
      # (its contents are not reprocessed for backrefs/regex).
      FROMSTR="$fromstr" TOSTR="$tostr" \
        perl -0777 -i -pe 's/\Q$ENV{FROMSTR}\E/$ENV{TOSTR}/g' "$tmp"
      notes+=("${n} × ${fromstr}  →  ${tostr}")
    done

    if cmp -s "$pth" "$tmp"; then rm -f "$tmp"; continue; fi   # no change

    print -r -- "• $f"
    for note in "${notes[@]}"; do print -r -- "    $note"; done

    if ! _validate_json "$tmp"; then
      print -u2 -r -- "    ! rewrite would produce invalid JSON — left unchanged"
      rm -f "$tmp"
      continue
    fi

    if (( apply )); then
      if (( backup )); then
        bak="$pth.bak-$(date +%Y%m%d%H%M%S)"
        cp -p -- "$pth" "$bak"
        print -r -- "    backup → ${bak:t}"
      fi
      cp -- "$tmp" "$pth"          # overwrite in place: keeps original perms/owner
      print -r -- "    updated"
      (( changed_total++ ))
    else
      print -r -- "    (would change)"
      (( would_change++ ))
    fi
    rm -f "$tmp"
  done

  print
  if (( apply )); then
    (( changed_total )) && print -r -- "Done — updated ${changed_total} file(s)." \
                        || print -r -- "Nothing to change — config dir is already consistent."
  else
    (( would_change )) && print -r -- "Dry-run — ${would_change} file(s) would change. Re-run with --apply to write." \
                       || print -r -- "Nothing to change — config dir is already consistent."
  fi
}

main "$@"
