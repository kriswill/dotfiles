# shellcheck shell=bash
# prune-generations: delete old profile generations before nix-gc's
# collect-only nix-collect-garbage. Loaded by modules/nixos/generations.nix
# into writeShellApplication.
#
# The system profile is pruned by boot history, not age. A generation stays
# when its system is one of:
#   - the current boot (/run/booted-system);
#   - one of the previous PREV_BOOTS systems that booted successfully, newest
#     first and distinct, other than the current boot's;
#   - the newest successfully booted system whose kernel semver
#     (MAJOR.MINOR.PATCH; a -zen1 or -rc1 suffix and the build do not count)
#     differs from the current boot's (the kernel fallback);
#   - the boot default, or the running system;
#   - the previous good switch: the newest other system that
#     switch-to-configuration finished switching to (it logs that only when
#     activation exited 0 with every unit started). Without such a record:
#     the newest earlier generation with a different system.
# A boot counts as successful when systemd logged "Startup finished"
# (MESSAGE_ID b07a249c…), which a boot stuck in emergency mode never reaches.
# Which system a boot ran comes from the kernel command line's init=. All of
# it is read from the persistent journal; if that cannot be read, the system
# profile is left alone.
#
# Every other profile keeps the old nix-gc rule, generations older than
# KEEP_DAYS (nix-env --delete-generations <N>d). Deletion always goes through
# nix-env, which refuses to delete a profile's current generation.
#
#   prune-generations [--dry] PREV_BOOTS KEEP_DAYS DIR…
set -euo pipefail

SYSTEM_PROFILE=/nix/var/nix/profiles/system
STARTUP_FINISHED=b07a249cd024414a82dd00cd181378ff # SD_MESSAGE_STARTUP_FINISHED

dry=0
if [ "${1:-}" = --dry ]; then
  dry=1
  shift
fi
if [ $# -lt 3 ]; then
  echo "usage: prune-generations [--dry] PREV_BOOTS KEEP_DAYS DIR…" >&2
  exit 2
fi
prev_boots=$1 keep_days=$2
shift 2

kernel_of() { # kernel_of <system>: its kernel's version (the modules directory name)
  local d
  for d in "$1"/kernel-modules/lib/modules/*; do
    if [ -d "$d" ]; then
      echo "${d##*/}"
      return
    fi
  done
}

semver_of() { # semver_of <system>: its kernel's MAJOR.MINOR.PATCH
  local v
  v="$(kernel_of "$1")"
  if [[ "$v" =~ ^([0-9]+)\.([0-9]+)(\.([0-9]+))? ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[4]:-0}"
  else
    echo "$v"
  fi
}

good_switches() { # systems switch-to-configuration finished switching to, newest first
  journalctl -t nixos -r -q --no-pager -o cat -g '^finished switching to system configuration /nix/store/' \
    | sed -n 's#^finished switching to system configuration \(/nix/store/[^/ ]*\).*#\1#p' || true
}

successful_boots() { # the system each earlier successful boot ran, newest first
  local id sys
  journalctl --list-boots --no-pager -o json | jq -r 'map(select(.index < 0)) | sort_by(-.index) | .[].boot_id' \
    | while IFS= read -r id; do
      if [ -z "$(journalctl -b "$id" -q --no-pager -o cat -n 1 MESSAGE_ID="$STARTUP_FINISHED" || true)" ]; then continue; fi
      sys="$(journalctl -b "$id" -k -q --no-pager -o cat -g '^Command line:' || true)"
      sys="$(grep -m1 -o 'init=/nix/store/[^/ ]*' <<<"$sys" || true)"
      if [ -n "$sys" ]; then echo "${sys#init=}"; fi
    done
}

keep_path() { # keep_path <system> <reason>: add to prune_system's `why` (dynamic scope)
  if [ -z "$1" ]; then return; fi
  if [ -n "${why[$1]:-}" ]; then why[$1]+=", $2"; else why[$1]=$2; fi
}

prune_system() {
  local profile=$SYSTEM_PROFILE link n cur prev sys booted booted_kernel running default found=0 kernel_found=0
  local -A gen_path=() why=() has_gen=() seen=()
  local -a gens=() del=() kept=() history=() switches=()
  cur="$(readlink "$profile")" # system-<N>-link, relative or absolute
  cur="${cur##*/}"
  cur="${cur#system-}"
  cur="${cur%-link}"
  for link in "$profile"-*-link; do
    [ -L "$link" ] || continue
    n="${link#"$profile"-}"
    n="${n%-link}"
    if [[ "$n" =~ ^[0-9]+$ ]]; then
      gens+=("$n")
      gen_path[$n]="$(readlink -f "$link")"
      has_gen[${gen_path[$n]}]=1
    fi
  done
  if [ "${#gens[@]}" -eq 0 ]; then return; fi
  mapfile -t gens < <(printf '%s\n' "${gens[@]}" | sort -n)

  # No readable boot history, no pruning.
  if ! journalctl --list-boots --no-pager -q >/dev/null 2>&1; then
    echo "$profile: could not read the boot history from the journal; leaving it alone" >&2
    return
  fi
  mapfile -t history < <(successful_boots)
  mapfile -t switches < <(good_switches)

  booted="$(readlink -f /run/booted-system)"
  booted_kernel="$(semver_of "$booted")"
  running="$(readlink -f /run/current-system)"
  default="${gen_path[$cur]:-}"
  keep_path "$booted" "current boot"
  keep_path "$running" "running"
  keep_path "$default" "boot default"
  # The previous good switch, or failing a record of one, the newest earlier
  # generation with a different system.
  prev=''
  for sys in "${switches[@]}"; do
    if [ "$sys" != "$running" ] && [ "$sys" != "$default" ] && [ -n "${has_gen[$sys]:-}" ]; then
      prev=$sys
      break
    fi
  done
  if [ -n "$prev" ]; then
    keep_path "$prev" "previous good switch"
  elif [[ "$cur" =~ ^[0-9]+$ ]]; then
    for n in "${gens[@]}"; do
      if [ "$n" -lt "$cur" ] && [ "${gen_path[$n]}" != "$default" ]; then prev=${gen_path[$n]}; fi
    done
    keep_path "$prev" "before the boot default; no switch on record"
  fi

  # Only systems that still have a generation can be kept, so only those count.
  for sys in "${history[@]}"; do
    if [ "$sys" = "$booted" ] || [ -n "${seen[$sys]:-}" ] || [ -z "${has_gen[$sys]:-}" ]; then continue; fi
    seen[$sys]=1
    if [ "$found" -lt "$prev_boots" ]; then
      found=$((found + 1))
      keep_path "$sys" "boot -$found"
    fi
    if [ "$kernel_found" -eq 0 ] && [ "$(semver_of "$sys")" != "$booted_kernel" ]; then
      kernel_found=1
      keep_path "$sys" "previous kernel $(semver_of "$sys")"
    fi
    if [ "$found" -ge "$prev_boots" ] && [ "$kernel_found" -eq 1 ]; then break; fi
  done

  for n in "${gens[@]}"; do
    if [ -n "${why[${gen_path[$n]}]:-}" ] || [ "$n" = "$cur" ]; then
      kept+=("$n (${why[${gen_path[$n]}]:-boot default})")
    else
      del+=("$n")
    fi
  done
  echo "$profile: keeping ${#kept[@]} of ${#gens[@]} generations:"
  printf '  gen %s\n' "${kept[@]}"
  if [ "${#del[@]}" -eq 0 ]; then return; fi
  echo "$profile: deleting generations ${del[*]}"
  if [ "$dry" -eq 0 ]; then
    nix-env --profile "$profile" --delete-generations "${del[@]}"
  fi
}

prune_by_age() { # prune_by_age <profile>: the old nix-gc rule
  local -a args=(--profile "$1" --delete-generations "${keep_days}d")
  if [ "$dry" -eq 1 ]; then args=(--dry-run "${args[@]}"); fi
  echo "$1: generations older than $keep_days days, except the one current then"
  nix-env "${args[@]}"
}

for dir in "$@"; do
  [ -d "$dir" ] || continue
  # A profile is a symlink whose target is one of its own generation links;
  # generation links themselves, and anything else, are skipped.
  while IFS= read -r -d '' p; do
    t="$(readlink "$p")"
    t="${t##*/}"
    if ! [[ "$t" =~ ^"${p##*/}"-[0-9]+-link$ ]]; then continue; fi
    if [ "$p" = "$SYSTEM_PROFILE" ]; then prune_system; else prune_by_age "$p"; fi
  done < <(find "$dir" -type l ! -name '*-[0-9]*-link' -print0)
done
