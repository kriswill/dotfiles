# shellcheck shell=bash
# Body of battlenet, the half of the launcher that runs on the host. Loaded
# verbatim by ./package.nix via builtins.readFile into writeShellApplication,
# which sets $BATTLENET_FHS (battlenet-proton inside the FHS runtime, see
# ./battlenet-proton.sh), $BATTLENET_DEFAULT_PREFIX and
# $BATTLENET_DEFAULT_CPUS, and puts notify-send and taskset on PATH.
#
# State lives outside the store:
#   $prefix               compat data (STEAM_COMPAT_DATA_PATH): pfx/ is the
#                         Wine prefix, version names the Proton that last
#                         upgraded it. Proton creates both on first use.
#   ~/.cache/battlenet/   the downloaded Battle.net-Setup.exe
#
# One prefix, one wineserver. Wine finds a prefix's server through a socket in
# /tmp/.wine-$UID/server-<dev>-<inode>, named after the prefix directory, and
# the FHS runtime shares the host's /tmp, so every invocation can reach the
# same server. Before starting anything this script looks for that server
# from any sandbox (find_servers). A second invocation joins it with Proton's
# runinprefix verb, which skips prefix setup. A server it can't reach (another
# sandbox, such as the umu entry) makes it refuse, because starting Wine anyway
# would put a second server on the prefix and the two would overwrite each
# other's registry.
#
# This runs outside the sandbox because inside it, in bwrap's user namespace,
# the kernel hides other processes' cwd and environ.
set -euo pipefail

usage() {
  cat <<'EOF'
usage: battlenet [COMMAND]

  (none)            start Battle.net, installing it first if it's missing;
                    if it's already running, bring it forward
  install           download Blizzard's installer and run it
  run CMD [ARG...]  run a program in the prefix (winecfg, regedit, an .exe)
  kill              stop everything running in the prefix

BATTLENET_PREFIX overrides the configured prefix for one run, and
BATTLENET_CPUS the configured CPU list (empty: no pinning).
EOF
}

prefix=${BATTLENET_PREFIX:-$BATTLENET_DEFAULT_PREFIX}
[[ -n $prefix ]] || prefix=${XDG_DATA_HOME:-$HOME/.local/share}/battlenet
[[ $prefix == /* ]] || prefix=$HOME/$prefix
export BATTLENET_PREFIX=$prefix
exe="$prefix/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"

say() {
  echo "battlenet: $1" >&2
  notify-send --app-name=Battle.net Battle.net "$1" 2>/dev/null || true
}

# The sandbox, run under `taskset -c` when a CPU list is set. Affinity is
# inherited by the sandbox, Proton, the wineserver and every Windows program
# Battle.net starts, so the whole session (WoW included) stays on those CPUs.
# Wine still reports every host CPU to Windows programs (WMI showed 24 logical
# processors while pinned to 12); WINE_CPU_TOPOLOGY changes what they see.
cpus=${BATTLENET_CPUS-$BATTLENET_DEFAULT_CPUS}
fhs=("$BATTLENET_FHS")
if [[ -n $cpus ]]; then
  if ! taskset -c "$cpus" true 2>/dev/null; then
    say "Invalid CPU list '$cpus' (BATTLENET_CPUS or programs.battlenet.cpus)"
    exit 2
  fi
  fhs=(taskset -c "$cpus" "$BATTLENET_FHS")
fi

# The prefix's wineservers, whatever sandbox they run in. A wineserver's
# working directory is its socket directory, so /proc finds it from any mount
# namespace (a `wineserver -w` waiter matches too, which is harmless). It is
# joinable when its /tmp is ours.
joinable=()
foreign=()
find_servers() {
  joinable=()
  foreign=()
  [[ -d $prefix/pfx ]] || return 0
  local dev ino name tmp d
  read -r dev ino < <(stat -L -c '%d %i' "$prefix/pfx")
  name=$(printf 'server-%x-%x' "$dev" "$ino")
  tmp=$(stat -L -c '%d:%i' /tmp)
  for d in /proc/[0-9]*; do
    [[ $(readlink "$d/cwd" 2>/dev/null) == */.wine-"$UID"/"$name" ]] || continue
    if [[ $(stat -L -c '%d:%i' "$d/root/tmp" 2>/dev/null) == "$tmp" ]]; then
      joinable+=("${d#/proc/}")
    else
      foreign+=("${d#/proc/}")
    fi
  done
}

refuse_foreign() {
  if ((${#foreign[@]})); then
    say "Wine is already running in $prefix from another launcher, such as the umu entry (wineserver ${foreign[*]}). Close it there, or run 'battlenet kill'."
    exit 1
  fi
}

# WINEPREFIX of the process at /proc/PID ($1). A Chromium main thread can exit
# before the rest, leaving a zombie whose own environ is unreadable while its
# threads keep the windows open, so fall back to the threads.
wineprefix_of() {
  local f kv
  for f in "$1/environ" "$1"/task/*/environ; do
    if { while IFS= read -r -d '' kv; do
      if [[ $kv == WINEPREFIX=* ]]; then
        printf '%s\n' "${kv#WINEPREFIX=}"
        return 0
      fi
    done <"$f"; } 2>/dev/null; then
      return 1 # readable, and not a Wine process
    fi
  done
  return 1
}

kill_prefix() {
  find_servers
  local servers=("${joinable[@]}" "${foreign[@]}") target d value pid i n=0
  # SIGTERM makes a wineserver save the registry and exit.
  if ((${#servers[@]})); then
    kill -TERM "${servers[@]}" 2>/dev/null || true
    for ((i = 0; i < 50; i++)); do
      for pid in "${servers[@]}"; do
        [[ -d /proc/$pid ]] && break
      done
      [[ -d /proc/$pid ]] || break
      sleep 0.1
    done
  fi
  # Its programs don't exit with it. Stop every process whose WINEPREFIX is
  # this prefix; signalling the process ID ends all of its threads.
  target=$(realpath -m "$prefix/pfx")
  for d in /proc/[0-9]*; do
    [[ -O $d ]] || continue
    value=$(wineprefix_of "$d") || continue
    [[ $(realpath -m "$value") == "$target" ]] || continue
    kill -KILL "${d#/proc/}" 2>/dev/null && n=$((n + 1))
  done
  if ((${#servers[@]} + n)); then
    say "Stopped Wine in $prefix (${#servers[@]} wineserver, $n processes)"
  else
    say "Nothing is running in $prefix"
  fi
}

# The invocation that starts the prefix's wineserver owns the session: it
# waits in the foreground, and Ctrl-C, SIGTERM or the terminal closing stops
# everything in the prefix, as quitting Battle.net would. Wine puts its
# programs in sessions of their own, so the terminal's SIGINT only reached
# Proton's Python wrapper, which died with a traceback while Battle.net ran
# on. A non-interactive shell starts background jobs with SIGINT ignored, so
# Proton no longer sees it, and the trap does the stopping. Invocations that
# join a running session don't own it, so interrupting one never takes the
# session down.
session=""
own_session() {
  "${fhs[@]}" "$@" &
  session=$!
  trap stop_session INT TERM HUP
  wait "$session"
}

# Kill our own child tree first (bwrap, Proton's Python), so Proton can't
# start more Wine after the sweep when the signal lands mid-setup, then stop
# the prefix: Battle.net and the wineserver live outside that tree.
stop_session() {
  trap - INT TERM HUP
  # Out of the job table, so bash doesn't report the kill below as
  # "line N: PID Killed ...".
  disown "$session" 2>/dev/null || true
  echo >&2
  kill_tree "$session"
  kill_prefix
  exit 130
}

kill_tree() {
  local child
  for child in $(pgrep -P "$1"); do
    kill_tree "$child"
  done
  kill -KILL "$1" 2>/dev/null || true
}

case ${1:-} in
  "")
    find_servers
    refuse_foreign
    if ((${#joinable[@]})); then
      if [[ ! -f $exe ]]; then
        say "Battle.net isn't installed in $prefix yet. Close what's running there, then start it again."
        exit 1
      fi
      # Joining the running session: in the same wineserver, a second
      # Battle.net.exe hands over to the running one, which comes forward.
      exec "${fhs[@]}" runinprefix "$exe"
    fi
    if [[ ! -f $exe ]]; then
      # The installer starts Battle.net when it finishes.
      own_session install
    else
      export STEAM_COMPAT_INSTALL_PATH=${exe%/*}
      own_session waitforexitandrun "$exe"
    fi
    ;;
  install)
    find_servers
    refuse_foreign
    if ((${#joinable[@]})); then
      say "Battle.net is running in $prefix. Close it, or run 'battlenet kill', then install again."
      exit 1
    fi
    own_session install
    ;;
  run)
    shift
    if [[ $# -eq 0 ]]; then
      usage >&2
      exit 2
    fi
    find_servers
    refuse_foreign
    if ((${#joinable[@]})); then
      exec "${fhs[@]}" runinprefix "$@"
    fi
    own_session waitforexitandrun "$@"
    ;;
  kill)
    kill_prefix
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
