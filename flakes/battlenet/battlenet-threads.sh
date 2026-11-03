# shellcheck shell=bash
# Body of battlenet-threads, which shows where a running game's threads run.
# Loaded verbatim by ./package.nix via builtins.readFile into
# writeShellApplication, which puts coreutils and procps on PATH.
#
# It only reads /proc and /sys, from the host, so it can run while you play.
# Run from a terminal during a session, it sits in app.slice, which the
# confinement holds off the game's CPUs, so the sampler doesn't compete with
# the game.
#
# A thread's CPU in /proc/PID/task/TID/stat is the one it last ran on, or is
# queued on while runnable. Sampling it only while the thread is runnable
# (state R) gives each thread's share of time per CPU, at the sampling
# interval's resolution: a proportion, not a trace.
set -euo pipefail

if [[ -t 1 ]]; then
  RED=$'\e[31m' GREEN=$'\e[32m' YELLOW=$'\e[33m' BLUE=$'\e[34m' NC=$'\e[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

usage() {
  cat <<'EOF'
usage: battlenet-threads [-d SECONDS] [-n THREADS] [-i SECONDS] [PID|NAME]

Where a running game's threads run: its CPU affinity, how many threads it and
its session have, then its busiest threads, sampled, with the CPUs and cores
they ran on next to each core's preferred-core ranking.

  PID|NAME     the process: a PID, or a process name matched exactly against
               the kernel's (at most 15 characters), oldest first
               (default WoW.exe)
  -d SECONDS   how long to sample, a whole number (default 8)
  -n THREADS   how many threads to sample, the main thread included
               (default 12)
  -i SECONDS   the pause between samples (default 0.01)
  -h, --help   this text
EOF
}

die() {
  echo "${RED}battlenet-threads: $1${NC}" >&2
  exit "${2:-1}"
}

target=WoW.exe duration=8 top=12 interval=0.01
while (($#)); do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    -d | -n | -i)
      (($# >= 2)) || die "$1 needs a value" 2
      case $1 in
        -d) duration=$2 ;;
        -n) top=$2 ;;
        -i) interval=$2 ;;
      esac
      shift 2
      ;;
    -*) die "unknown option $1 (see --help)" 2 ;;
    *)
      target=$1
      shift
      ;;
  esac
done
[[ $duration =~ ^[1-9][0-9]*$ ]] || die "-d takes a whole number of seconds, not '$duration'" 2
[[ $top =~ ^[1-9][0-9]*$ ]] || die "-n takes a number of threads, not '$top'" 2
[[ $interval =~ ^([0-9]+\.?[0-9]*|\.[0-9]+)$ ]] || die "-i takes seconds, not '$interval'" 2

if [[ $target =~ ^[0-9]+$ ]]; then
  pid=$target
else
  pid=$(pgrep -o -x -- "$target") || die "no process named $target is running"
fi
[[ -d /proc/$pid/task ]] || die "process $pid isn't running"
read -r comm <"/proc/$pid/comm"

# Microseconds since the epoch, without a fork. EPOCHREALTIME's separator
# follows the locale.
now_us() {
  REPLY=${EPOCHREALTIME/[.,]/}
}

# Sets `fields` to /proc/PID/task/TID/stat's fields after the command name
# (which may hold spaces and parentheses), so fields[0] is the state, [11]
# and [12] the user and system time in USER_HZ ticks (100 a second on Linux)
# and [36] the CPU. Fails when the thread is gone.
read_stat() {
  local line
  { read -r line <"/proc/$pid/task/$1/stat"; } 2>/dev/null || return 1
  read -ra fields <<<"${line##*) }"
}

# Sets `migrations` and `switches` from /proc/PID/task/TID/sched, or to "-"
# when the kernel doesn't provide them.
read_sched() {
  local key _ value
  migrations=- switches=-
  while read -r key _ value; do
    case $key in
      se.nr_migrations) migrations=$value ;;
      nr_switches) switches=$value ;;
    esac
  done 2>/dev/null <"/proc/$pid/task/$1/sched" || true
}

# Sets REPLY to the Cpus_allowed_list line of a /proc status file.
read_affinity() {
  local key value
  REPLY=
  while read -r key value; do
    if [[ $key == Cpus_allowed_list: ]]; then
      REPLY=$value
      return 0
    fi
  done 2>/dev/null <"$1" || true
}

# The CPUs in a kernel CPU list such as "0-5,12-17", one per line.
expand_cpus() {
  local ranges range cpu
  IFS=, read -ra ranges <<<"$1"
  for range in "${ranges[@]}"; do
    for ((cpu = ${range%-*}; cpu <= ${range#*-}; cpu++)); do
      echo "$cpu"
    done
  done
}

# Sets REPLY to VALUE per second over the sampling window, to one decimal.
rate() {
  local tenths
  if [[ $1 == - ]]; then
    REPLY=-
    return 0
  fi
  tenths=$(($1 * 10000000 / elapsed_us))
  printf -v REPLY '%d.%d' $((tenths / 10)) $((tenths % 10))
}

# Every thread's CPU time now, and again a second later: the busiest threads
# over that second are the ones sampled, the main thread always among them.
declare -A start_ticks=() busy=()
now_us
run_start_us=$REPLY
for path in /proc/"$pid"/task/*; do
  tid=${path##*/}
  read_stat "$tid" || continue
  start_ticks[$tid]=$((fields[11] + fields[12]))
done
sleep 1
for tid in "${!start_ticks[@]}"; do
  read_stat "$tid" || continue
  busy[$tid]=$((fields[11] + fields[12] - start_ticks[$tid]))
done
mapfile -t sampled < <(
  echo "$pid"
  for tid in "${!busy[@]}"; do
    [[ $tid == "$pid" ]] || echo "${busy[$tid]} $tid"
  done | sort -rn | head -n $((top - 1)) | cut -d' ' -f2
)

declare -A ticks0=() migrations0=() switches0=() hist=() seen_cpu=() running=()
for tid in "${sampled[@]}"; do
  read_stat "$tid" || continue
  ticks0[$tid]=$((fields[11] + fields[12]))
  read_sched "$tid"
  migrations0[$tid]=$migrations switches0[$tid]=$switches
done

now_us
sample_start_us=$REPLY
end_us=$((REPLY + duration * 1000000))
rounds=0
while now_us && ((REPLY < end_us)); do
  for tid in "${sampled[@]}"; do
    read_stat "$tid" || continue
    if [[ ${fields[0]} == R ]]; then
      cpu=${fields[36]}
      hist[$tid,$cpu]=$((${hist[$tid,$cpu]:-0} + 1))
      running[$tid]=$((${running[$tid]:-0} + 1))
      seen_cpu[$cpu]=1
    fi
  done
  rounds=$((rounds + 1))
  sleep "$interval"
done
now_us
elapsed_us=$((REPLY - sample_start_us))
run_s=$(((REPLY - run_start_us + 500000) / 1000000))

# The whole process: threads, which of them ran since the start, and which
# don't share the main thread's affinity (a thread that widened its own, as
# WoW's did before WINE_CPU_TOPOLOGY).
read_affinity "/proc/$pid/status"
affinity=$REPLY
threads=0 ran=0
declare -A other_affinity=()
for path in /proc/"$pid"/task/*; do
  tid=${path##*/}
  read_stat "$tid" || continue
  threads=$((threads + 1))
  if ((fields[11] + fields[12] > ${start_ticks[$tid]:-0})); then
    ran=$((ran + 1))
  fi
  read_affinity "$path/status"
  if [[ -n $REPLY && $REPLY != "$affinity" ]]; then
    other_affinity[$REPLY]=$((${other_affinity[$REPLY]:-0} + 1))
  fi
done

# The session: the process's cgroup (with the launcher's CPU list, a scope in
# battlenet.slice that holds the whole session).
cgroup=
while IFS= read -r line; do
  if [[ $line == 0::* ]]; then
    cgroup=${line#0::}
  fi
done <"/proc/$pid/cgroup"

printf '%s%s (pid %s)%s\n' "$BLUE" "$comm" "$pid" "$NC"
if ((${#other_affinity[@]})); then
  printf '  affinity  %s, %s%d threads on other CPUs:' "$affinity" "$YELLOW" \
    "$(($(IFS=+; echo "${other_affinity[*]}")))"
  for list in "${!other_affinity[@]}"; do
    printf ' %s (%d)' "$list" "${other_affinity[$list]}"
  done
  printf '%s\n' "$NC"
else
  printf '  affinity  %s, every thread\n' "$affinity"
fi
printf '  threads   %d, %d of them ran in the last %d s\n' "$threads" "$ran" "$run_s"
if [[ -n $cgroup && -r /sys/fs/cgroup$cgroup/cgroup.threads ]]; then
  mapfile -t cgroup_procs <"/sys/fs/cgroup$cgroup/cgroup.procs"
  mapfile -t cgroup_threads <"/sys/fs/cgroup$cgroup/cgroup.threads"
  printf '  session   %d processes, %d threads in %s\n' \
    "${#cgroup_procs[@]}" "${#cgroup_threads[@]}" "${cgroup#*/user@*.service/}"
fi

printf '\n%sBusiest threads%s, %d samples over %d.%d s (every %s s); ON CPU counts\n' \
  "$BLUE" "$NC" "$rounds" $((elapsed_us / 1000000)) $((elapsed_us / 100000 % 10)) "$interval"
printf 'the samples a thread was running or runnable in, per CPU.\n'
printf '%-9s %-16s %6s %7s %8s  %s\n' TID NAME CPU% MIGR/s SW/s 'ON CPU (cpu:samples)'
for tid in "${sampled[@]}"; do
  [[ -n ${ticks0[$tid]+set} ]] || continue
  read_stat "$tid" || continue
  { read -r name <"/proc/$pid/task/$tid/comm"; } 2>/dev/null || name='?'
  rate $((fields[11] + fields[12] - ticks0[$tid]))
  cpu_pct=$REPLY
  read_sched "$tid"
  if [[ $migrations == - || ${migrations0[$tid]:--} == - ]]; then
    migr_s=- sw_s=-
  else
    rate $((migrations - migrations0[$tid]))
    migr_s=$REPLY
    rate $((switches - switches0[$tid]))
    sw_s=$REPLY
  fi
  on_cpu=$(
    for cpu in "${!seen_cpu[@]}"; do
      count=${hist[$tid,$cpu]:-0}
      ((count == 0)) || echo "$count $cpu"
    done | sort -rn | while read -r count cpu; do printf '%s:%s ' "$cpu" "$count"; done
  )
  color=
  if [[ $tid == "$pid" ]]; then
    color=$GREEN
  fi
  printf '%s%-9s %-16.16s %6s %7s %8s  %s%s\n' "$color" "$tid" "$name" "$cpu_pct" "$migr_s" "$sw_s" "${on_cpu% }" "$NC"
done

# The same samples by physical core (SMT siblings together), next to the
# core's preferred-core ranking: amd-pstate's prefcore ranking, or the CPPC
# highest_perf it comes from. The scheduler favours idle cores with a higher
# rank.
declare -A core_cpus=() core_rank=() core_main=() core_all=()
mapfile -t cpus < <({
  expand_cpus "$affinity"
  printf '%s\n' "${!seen_cpu[@]}"
} | sort -nu)
for cpu in "${cpus[@]}"; do
  sys=/sys/devices/system/cpu/cpu$cpu
  siblings=$cpu
  { read -r siblings <"$sys/topology/thread_siblings_list"; } 2>/dev/null || true
  if [[ -z ${core_cpus[$siblings]+set} ]]; then
    core_cpus[$siblings]=$siblings
    rank=-
    { read -r rank <"$sys/cpufreq/amd_pstate_prefcore_ranking"; } 2>/dev/null ||
      { read -r rank <"$sys/acpi_cppc/highest_perf"; } 2>/dev/null || true
    core_rank[$siblings]=$rank core_main[$siblings]=0 core_all[$siblings]=0
  fi
  for tid in "${sampled[@]}"; do
    count=${hist[$tid,$cpu]:-0}
    core_all[$siblings]=$((core_all[$siblings] + count))
    if [[ $tid == "$pid" ]]; then
      core_main[$siblings]=$((core_main[$siblings] + count))
    fi
  done
done
main_total=${running[$pid]:-0}
all_total=0
for tid in "${!running[@]}"; do
  all_total=$((all_total + running[$tid]))
done
pct() { # COUNT TOTAL
  if (($2)); then REPLY="$(($1 * 100 / $2))%"; else REPLY=-; fi
}

printf "\n%sBy core%s, highest rank first (RANK: the firmware's preferred-core ranking)\n" "$BLUE" "$NC"
printf '%-8s %5s %12s %12s\n' CPUS RANK 'MAIN THREAD' 'ALL SAMPLED'
for siblings in "${!core_cpus[@]}"; do
  rank=${core_rank[$siblings]}
  echo "${rank/#-/0} $siblings"
done | sort -k1,1nr -k2,2V | while read -r _ siblings; do
  pct "${core_main[$siblings]}" "$main_total"
  main="${core_main[$siblings]} $REPLY"
  pct "${core_all[$siblings]}" "$all_total"
  all="${core_all[$siblings]} $REPLY"
  printf '%-8s %5s %12s %12s\n' "$siblings" "${core_rank[$siblings]}" "$main" "$all"
done
