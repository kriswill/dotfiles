# shellcheck shell=bash
# Body of battlenet-confine-nix, which battlenet-confine-nix@.service runs as
# root for the launcher's confinement (confine_target in ./battlenet.sh).
# Loaded by ./package.nix into writeShellApplication, which sets
# $BATTLENET_DEFAULT_CPUS (programs.battlenet.cpus). It sets
# nix-daemon.service's AllowedCPUs to its argument, the unit's instance: a CPU
# list with commas as underscores ("6-11_18-23"), or "none" to clear it.
#
# polkit lets any member of `users` start the unit with an instance of their
# choosing, so the only list it takes is the online CPUs outside
# programs.battlenet.cpus. The most a user can do with it is hold Nix builds
# off the game's CPUs or let them back.
set -euo pipefail

# The CPUs in a CPU list such as "0-5,12-17", one per line (as in
# ./battlenet.sh).
expand_cpus() {
  local ranges range cpu
  IFS=, read -ra ranges <<<"$1"
  for range in "${ranges[@]}"; do
    for ((cpu = ${range%-*}; cpu <= ${range#*-}; cpu++)); do
      echo "$cpu"
    done
  done
}

if [[ $1 == none ]]; then
  cpus=""
elif [[ $1 =~ ^[0-9]+(-[0-9]+)?(_[0-9]+(-[0-9]+)?)*$ ]]; then
  cpus=${1//_/,}
  read -r online </sys/devices/system/cpu/online
  declare -A want=() got=()
  for cpu in $(expand_cpus "$online"); do
    want[$cpu]=1
  done
  for cpu in $(expand_cpus "$BATTLENET_DEFAULT_CPUS"); do
    unset "want[$cpu]"
  done
  for cpu in $(expand_cpus "$cpus"); do
    got[$cpu]=1
  done
  for cpu in "${!want[@]}" "${!got[@]}"; do
    if [[ -z ${want[$cpu]-} || -z ${got[$cpu]-} ]]; then
      echo "battlenet-confine-nix: $cpus isn't the online CPUs ($online) outside programs.battlenet.cpus (${BATTLENET_DEFAULT_CPUS:-unset})" >&2
      exit 2
    fi
  done
else
  echo "battlenet-confine-nix: not a CPU list: $1" >&2
  exit 2
fi
systemctl set-property --runtime nix-daemon.service AllowedCPUs="$cpus"
