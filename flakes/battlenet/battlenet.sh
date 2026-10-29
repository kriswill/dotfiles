# shellcheck shell=bash
# Body of battlenet, the half of the launcher that runs on the host. Loaded
# verbatim by ./package.nix via builtins.readFile into writeShellApplication,
# which sets $BATTLENET_FHS (battlenet-proton inside the FHS runtime, see
# ./battlenet-proton.sh), $BATTLENET_DEFAULT_PREFIX, $BATTLENET_DEFAULT_CPUS
# and $BATTLENET_DEFAULT_CONFINE, and puts notify-send, taskset, flock,
# systemctl and systemd-run on PATH. battlenet-confine@.service runs it too,
# as `battlenet _confine` (see confine_target).
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

BATTLENET_PREFIX overrides the configured prefix for one run,
BATTLENET_CPUS the configured CPU list (empty: no pinning), and
BATTLENET_CONFINE the user slices (and nix-daemon.service) held off those
CPUs while the session runs (space-separated; empty: no confinement).
EOF
}

prefix=${BATTLENET_PREFIX:-$BATTLENET_DEFAULT_PREFIX}
[[ -n $prefix ]] || prefix=${XDG_DATA_HOME:-$HOME/.local/share}/battlenet
[[ $prefix == /* ]] || prefix=$HOME/$prefix
export BATTLENET_PREFIX=$prefix
exe="$prefix/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"

# stderr can be a terminal that has closed (see stop_session).
say() {
  echo "battlenet: $1" >&2 || true
  notify-send --app-name=Battle.net Battle.net "$1" 2>/dev/null || true
}

# The CPUs in a kernel CPU list such as "0-5,12-17" (no strides), one per
# line.
expand_cpus() {
  local ranges range cpu
  IFS=, read -ra ranges <<<"$1"
  for range in "${ranges[@]}"; do
    for ((cpu = ${range%-*}; cpu <= ${range#*-}; cpu++)); do
      echo "$cpu"
    done
  done
}

# The CPUs of list $1 that aren't in list $2, as a kernel CPU list such as
# "6-11,18-23"; empty when $2 covers all of $1.
cpus_minus() {
  local -A drop=()
  local cpu first=-1 last=-1 ranges=()
  for cpu in $(expand_cpus "$2"); do
    drop[$cpu]=1
  done
  # The trailing -1 closes the last range.
  for cpu in $(expand_cpus "$1") -1; do
    [[ -z ${drop[$cpu]-} ]] || continue
    if ((last >= 0 && cpu == last + 1)); then
      last=$cpu
      continue
    fi
    if ((last > first)); then
      ranges+=("$first-$last")
    elif ((last >= 0)); then
      ranges+=("$first")
    fi
    first=$cpu
    last=$cpu
  done
  local IFS=,
  echo "${ranges[*]}"
}

# Cpus_allowed_list, the kernel's normalised CPU list (no strides, e.g.
# "0-5,12-17"), from a /proc/PID/status text on stdin.
cpus_allowed() {
  local key value
  while IFS=$'\t' read -r key value; do
    if [[ $key == Cpus_allowed_list: ]]; then
      echo "$value"
    fi
  done
}

# Confinement keeps other work off the session's CPUs while it runs. Affinity
# can't: whatever started outside this launcher, such as the sccache server
# that spawns the compilers, keeps every CPU. A cgroup cpuset can, because the
# kernel holds every process in a cgroup to its CPUs. Each target in $confine
# (BATTLENET_CONFINE, or programs.battlenet.confineSlices and
# confineNixDaemon), a user slice or nix-daemon.service, is held to the online
# CPUs outside the sessions' while any session runs.
#
# systemd keeps track of that, not this script. Every invocation that starts
# Wine runs the sandbox in a transient scope in battlenet.slice, and the scope
# upholds battlenet-confine@TARGET:CPUS.service for each target. CPUS is the
# session's list with commas as underscores, since a unit name can't hold a
# comma. The unit is StopWhenUnneeded=, so systemd starts it with the first
# scope that upholds it and stops it after the last one ends, however the
# launcher itself ended. Its start and its stop both run confine_target.
# Upholds= rather than Wants=: a session started while the unit was still
# stopping after the previous one (`battlenet kill && battlenet`) lost its
# start job to that stop and ran unconfined. Upholds= starts the unit again
# once the stop is done.
#
# The scope also keeps the session out of confined slices. Started from a
# terminal in one, it would otherwise inherit that slice's cpuset, and taskset
# to the session's CPUs would fail with EINVAL. In --scope mode systemd-run
# registers its own PID as the scope and then execs the command, so the PID
# own_session waits on and kills is still the sandbox's.
# --expand-environment=no passes `run` arguments that contain `$` on
# unchanged. Without a CPU list nothing runs in a scope.
#
# The sandbox, run under `taskset -c` when a CPU list is set. Affinity is
# inherited by the sandbox, Proton, the wineserver and every Windows program
# Battle.net starts. It is only a starting point, though: a process may widen
# its own affinity. Wine reports every host CPU to Windows programs unless
# told otherwise, so when WoW set its process affinity to "all processors",
# 76 of its 99 threads (job pools, QUIC workers, vkd3d queues) and the
# WowVoiceProxy it started moved to all 24 CPUs. WINE_CPU_TOPOLOGY
# (count:cpu,cpu,...) makes Wine report only the pinned CPUs, so "all
# processors" means those. Wine reports them as separate cores, without SMT
# pairing. It's derived from the list unless already set (an empty value
# turns it off).
#
# Only the commands that start Wine call this.
fhs=("$BATTLENET_FHS")
prepare_wine() {
  local cpus confine=() scope=() status allowed own online target unit list
  local run=(systemd-run --user --scope --quiet --collect --expand-environment=no
    --slice=battlenet.slice)
  cpus=${BATTLENET_CPUS-$BATTLENET_DEFAULT_CPUS}
  [[ -n $cpus ]] || return 0
  read -ra confine <<<"${BATTLENET_CONFINE-$BATTLENET_DEFAULT_CONFINE}"
  # The list is checked in such a scope, where the session will run: in a
  # slice that a running session confines (a terminal's), the cpuset would
  # narrow it or refuse it. If only the scope fails, the launch goes on
  # without it.
  if status=$("${run[@]}" taskset -c "$cpus" cat /proc/self/status 2>/dev/null); then
    scope=("${run[@]}")
  elif status=$(taskset -c "$cpus" cat /proc/self/status 2>/dev/null); then
    if ((${#confine[@]})); then
      say "Not confining ${confine[*]}: systemd-run couldn't start a scope"
      confine=()
    fi
  else
    # Both fail for a list without an online CPU in it, and in a shell held to
    # other CPUs, for a list outside those.
    own=$(cpus_allowed </proc/$$/status)
    read -r online </sys/devices/system/cpu/online
    if [[ $own != "$online" && $cpus =~ ^[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*$ &&
      $(cpus_minus "$online" "$cpus") != "$online" ]]; then
      say "Can't pin to CPUs '$cpus' here: this shell is held to CPUs $own (a running session confines its slice), and systemd-run couldn't start a scope outside it"
    else
      say "Invalid CPU list '$cpus' (BATTLENET_CPUS or programs.battlenet.cpus)"
    fi
    exit 2
  fi
  allowed=$(cpus_allowed <<<"$status")
  if ((${#confine[@]})) &&
    [[ $(systemctl --user show --property=LoadState --value battlenet-confine@check.service) != loaded ]]; then
    say "Not confining ${confine[*]}: battlenet-confine@.service isn't installed (programs.battlenet installs it)"
    confine=()
  fi
  for target in "${confine[@]}"; do
    if [[ $target == battlenet.slice || $target == -.slice ]]; then
      say "Not confining $target: the session runs inside it"
      continue
    fi
    if [[ $target != nix-daemon.service && ! $target =~ ^[A-Za-z0-9_.-]+\.slice$ ]]; then
      say "Not confining $target: only user slices and nix-daemon.service can be confined"
      continue
    fi
    unit=battlenet-confine@$target:${allowed//,/_}.service
    # systemd's limit. The probe doesn't name these units, so past it the
    # launch itself would fail.
    if ((${#unit} > 255)); then
      say "Not confining $target: with CPUs $allowed, its unit's name would be too long for systemd"
      continue
    fi
    scope+=(--property="Upholds=$unit" --property="Before=$unit")
  done
  if ((${#scope[@]})); then
    scope+=(--)
  fi
  fhs=("${scope[@]}" taskset -c "$cpus" "$BATTLENET_FHS")
  if [[ -z ${WINE_CPU_TOPOLOGY+set} ]]; then
    mapfile -t list < <(expand_cpus "$allowed")
    WINE_CPU_TOPOLOGY="${#list[@]}:$(
      IFS=,
      echo "${list[*]}"
    )"
    export WINE_CPU_TOPOLOGY
  fi
}

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

# `battlenet _confine TARGET:CPUS`, run by battlenet-confine@TARGET:CPUS.service
# as it starts and after it stops. Under a lock, it holds TARGET to the online
# CPUs outside those of every session that confines it: the CPUS of TARGET's
# units that are active or starting. A starting unit counts itself and a
# stopping one doesn't, so the last stop clears AllowedCPUs. Clearing rather
# than restoring an earlier value is right because the launcher owns that
# property on its targets. A user slice is set through the user's systemd,
# which needs the cpuset controller delegated to it for that
# (programs.battlenet.confineSlices adds it to user@.service).
# nix-daemon.service belongs to the system, so battlenet-confine-nix@.service
# sets it as root, which polkit lets the user start
# (programs.battlenet.confineNixDaemon). That only holds it off
# programs.battlenet.cpus, so sessions on other CPUs (BATTLENET_CPUS) leave it
# as it is. It counts this user's sessions only, which suits a desktop with one
# player. systemd applies AllowedCPUs before it replies, so the cpuset is
# checked right after. Problems are reported, not returned: the session runs
# either way.
confine_target() {
  local target=${1%:*} units unit instance sessions=() others="" online want cg
  local effective
  exec 9>"$XDG_RUNTIME_DIR/battlenet-confine.lock"
  flock 9
  # Without the sessions, any value would be a guess.
  if ! units=$(systemctl --user list-units --plain --no-legend \
    --state=active,activating 'battlenet-confine@*.service'); then
    say "Couldn't list the sessions confining $target, so its CPUs stay as they are"
    return 0
  fi
  while read -r unit _; do
    instance=${unit#battlenet-confine@}
    instance=${instance%.service}
    if [[ ${instance%:*} == "$target" ]]; then
      sessions+=("${instance##*:}")
    fi
  done <<<"$units"
  read -r online </sys/devices/system/cpu/online
  if ((${#sessions[@]})); then
    sessions=("${sessions[@]//_/,}")
    others=$(cpus_minus "$online" "$(
      IFS=,
      echo "${sessions[*]}"
    )")
    if [[ -z $others ]]; then
      say "Not confining $target: the sessions have every online CPU"
    fi
  fi
  if [[ $target == nix-daemon.service ]]; then
    want=$(cpus_minus "$online" "$BATTLENET_DEFAULT_CPUS")
    if [[ -n $others && $others != "$want" ]]; then
      say "Leaving nix-daemon.service as it is: it can be held to CPUs $want (outside programs.battlenet.cpus), not $others"
      return 0
    fi
    unit=battlenet-confine-nix@${others:-none}.service
    if ! systemctl start --no-ask-password "${unit//,/_}"; then
      say "Couldn't set nix-daemon.service's CPUs (programs.battlenet.confineNixDaemon allows it)"
      return 0
    fi
    # Empty while the socket-activated daemon isn't running. It gets the
    # CPUs when it starts.
    cg=$(systemctl show --property=ControlGroup --value nix-daemon.service) || cg=""
  else
    if ! systemctl --user set-property --runtime "$target" AllowedCPUs="$others"; then
      say "Couldn't set $target's CPUs to '$others'"
      return 0
    fi
    cg=$(systemctl --user show --property=ControlGroup --value "$target") || cg=""
  fi
  [[ -n $others && -n $cg ]] || return 0
  if [[ ! -e /sys/fs/cgroup$cg/cpuset.cpus.effective ]]; then
    if [[ $target == nix-daemon.service ]]; then
      say "Not confining nix-daemon.service: its cgroup has no cpuset controller"
    else
      say "Not confining $target: the user's systemd has no cpuset controller. programs.battlenet.confineSlices delegates it, and the switch hands it over (so does 'systemctl --user daemon-reexec' after one)"
    fi
    return 0
  fi
  effective=$(<"/sys/fs/cgroup$cg/cpuset.cpus.effective") || effective=""
  if [[ $effective != "$others" ]]; then
    say "$target runs on CPUs ${effective:-(none)}, not $others"
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
# the prefix: Battle.net and the wineserver live outside that tree. A failure
# mustn't end the handler early: once the terminal has closed, even the
# newline below fails (EIO), and under set -e that exited before anything was
# stopped, leaving Battle.net running. Nor may SIGPIPE, which kills the shell
# whatever set -e says: with `battlenet 2>&1 | tee log`, Ctrl-C ends tee too,
# and the newline goes to a pipe nobody reads.
stop_session() {
  set +e
  trap '' PIPE
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
    if ((${#joinable[@]})) && [[ ! -f $exe ]]; then
      say "Battle.net isn't installed in $prefix yet. Close what's running there, then start it again."
      exit 1
    fi
    prepare_wine
    if ((${#joinable[@]})); then
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
    prepare_wine
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
    prepare_wine
    if ((${#joinable[@]})); then
      exec "${fhs[@]}" runinprefix "$@"
    fi
    own_session waitforexitandrun "$@"
    ;;
  kill)
    # Confinement ends with the session's scope, once its Wine has exited.
    kill_prefix
    ;;
  _confine)
    confine_target "${2:?usage: battlenet _confine TARGET:CPUS}"
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
