# shellcheck shell=bash
# battlenet-wow-backup: commit each World of Warcraft client's settings to git.
# Run through writeShellApplication (strict mode, PATH; see ./package.nix),
# with $BATTLENET_DEFAULT_PREFIX, $BATTLENET_WOW_DIR and $BATTLENET_WOW_CLIENTS
# set from the module's options.
#
# A WoW client (_retail_, _forever_, ...) keeps what's worth keeping in three
# folders of its own: WTF (settings, macros, addons' saved variables), Fonts
# and Interface (addons). Each client gets a git repository whose work tree is
# the client's folder and whose .git lives somewhere else. Nothing is written
# into the game folder, not even a .gitignore: Battle.net locks and rewrites
# files there, and the "only these folders" rule sits in the repository's
# info/exclude.
#
# The client's folder is worked out from the launcher's prefix on every run,
# and written back to the repository's core.worktree, which is what plain
# `git -C REPO status` goes by. A path kept in the repository alone goes stale
# when the prefix moves: every backup then fails, and so does `git -C`.
#
# A client that fails doesn't stop the others. The exit status is non-zero if
# any failed, so the unit that runs this shows it.

usage() {
  cat <<'EOF'
Usage: battlenet-wow-backup [CLIENT | CLIENT=REPO]...

Commits what changed in each WoW client's WTF, Fonts and Interface folders to
that client's git repository, creating the repository the first time. With no
arguments: every configured client.

  CLIENT        a configured client folder, such as _retail_
  CLIENT=REPO   back CLIENT up into the repository in directory REPO (relative:
                under your home), configured or not

BATTLENET_PREFIX overrides the configured prefix for one run.
EOF
}

# The same prefix the launcher uses (./battlenet.sh).
prefix=${BATTLENET_PREFIX:-$BATTLENET_DEFAULT_PREFIX}
[[ -n $prefix ]] || prefix=${XDG_DATA_HOME:-$HOME/.local/share}/battlenet
[[ $prefix == /* ]] || prefix=$HOME/$prefix
wow=$prefix/pfx/$BATTLENET_WOW_DIR

# $BATTLENET_WOW_CLIENTS: one CLIENT=REPO per line.
declare -A configured=()
names=()
while IFS='=' read -r client repo; do
  [[ -n $client ]] || continue
  configured[$client]=$repo
  names+=("$client")
done <<<"$BATTLENET_WOW_CLIENTS"

jobs=()
for arg in "$@"; do
  case $arg in
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      usage >&2
      exit 2
      ;;
    *=*) jobs+=("$arg") ;;
    *)
      if [[ ! -v configured[$arg] ]]; then
        echo "battlenet-wow-backup: $arg isn't a configured client (${names[*]:-none are}); give CLIENT=REPO" >&2
        exit 2
      fi
      jobs+=("$arg=${configured[$arg]}")
      ;;
  esac
done
if (($# == 0)); then
  for client in "${names[@]}"; do
    jobs+=("$client=${configured[$client]}")
  done
  if ((${#jobs[@]} == 0)); then
    echo "battlenet-wow-backup: no clients are configured; give CLIENT=REPO" >&2
    exit 2
  fi
fi

backup() {
  local client=$1 repo=$2 tree gitdir current summary="" dir count total stamp
  [[ $repo == /* ]] || repo=$HOME/$repo
  tree=$wow/$client
  gitdir=$repo/.git

  if [[ ! -d $tree ]]; then
    # No prefix and no earlier backups: this user doesn't play here.
    if [[ ! -d $prefix && ! -d $gitdir ]]; then
      echo "$client: no Battle.net prefix at $prefix, so nothing to back up"
      return 0
    fi
    echo "$client: no client folder at $tree" >&2
    return 1
  fi

  if [[ ! -d $gitdir ]]; then
    git init --quiet --initial-branch=main "$repo"
    # Wine's files carry mode bits that mean nothing.
    git config --file "$gitdir/config" core.fileMode false
    cat >"$gitdir/info/exclude" <<'EOF'
# The work tree is a WoW client folder (core.worktree). Ignore everything at
# its root...
/*
# ...except the three folders that hold settings.
!/WTF/
!/Fonts/
!/Interface/

# WoW's own backups of saved variables.
*.bak
EOF
    echo "$client: new repository in $repo"
  fi

  current=$(git config --file "$gitdir/config" core.worktree || true)
  if [[ $current != "$tree" ]]; then
    git config --file "$gitdir/config" core.worktree "$tree"
    echo "$client: the work tree is now $tree${current:+ (was $current)}"
  fi

  g() { git -C "$tree" --git-dir="$gitdir" --work-tree="$tree" "$@"; }

  # Everything the exclude rules allow.
  g add --all
  if g diff --cached --quiet; then
    echo "$client: no changes"
    return 0
  fi

  for dir in WTF Fonts Interface; do
    count=$(g diff --cached --name-only -- "$dir" | wc -l)
    summary+="${summary:+, }$dir: $count"
  done
  total=$(g diff --cached --name-only | wc -l)
  stamp=$(date '+%Y-%m-%d %H:%M:%S')

  g commit --quiet -m "WoW backup $stamp ($total files)" -m "$summary"
  echo "$client: committed $total files ($summary)"
}

status=0
for job in "${jobs[@]}"; do
  client=${job%%=*}
  repo=${job#*=}
  # In a subshell with its own `set -e`, and not as part of an `||` list,
  # where bash ignores -e: a failing git stops that client's backup at once.
  set +e
  (
    set -e
    backup "$client" "$repo"
  )
  rc=$?
  set -e
  if ((rc != 0)); then
    echo "$client: backup failed (exit $rc)" >&2
    status=1
  fi
done
exit "$status"
