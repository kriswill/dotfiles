# shellcheck shell=bash
# Body of `nrs2`, a prototype replacement for nrs (nh os switch / nh darwin
# switch), run side by side with it for comparison on NixOS and nix-darwin.
# Loaded verbatim by pkgs/nrs2.nix via builtins.readFile into
# writeShellApplication (which prepends the shebang and the runtimeInputs PATH,
# and runs shellcheck at build time). No Nix interpolation lives here — keep it
# plain bash.
#
# Same stages and order as nh, per OS:
#   NixOS   build (nom) → diff (dix) → validate → switch-to-configuration test
#           → system profile → switch-to-configuration boot
#   darwin  build (nom) → diff (dix) → validate → system profile
#           → <new generation>/sw/bin/darwin-rebuild activate
# What changes, each a finding in docs/nrs-pipeline.html:
#   - activation output is streamed live, not captured (F1) — both OSes;
#   - every exit ends with a state report and per-stage timings (F4, F12) —
#     both OSes; failed units, kernel and PAM glibc drift are NixOS-only;
#   - NixOS only: activation runs as a transient unit under PID 1
#     (systemd-run), so Ctrl-C or a lost terminal detaches instead of killing
#     it mid-plan (F3); a watchdog names pending jobs when it stalls (F2); an
#     interrupted earlier plan is announced before it replays (F5). launchd has
#     no systemd-run equivalent wired here, so on darwin Ctrl-C interrupts
#     activation exactly as it does under nh.
#
#   nrs2 [--dry | --test] [nix build args…]
#     --dry   build, diff and validate only; no root (like nrb)
#     --test  NixOS: activate without touching the profile or GRUB (like nrt)
#             darwin: darwin-rebuild check — run system.checks, no activation
set -euo pipefail

RED=$'\e[1;31m' GREEN=$'\e[1;32m' YELLOW=$'\e[1;33m' BLUE=$'\e[1;34m' NC=$'\e[0m'
if [ ! -t 2 ]; then RED='' GREEN='' YELLOW='' BLUE='' NC=''; fi

SYSTEM_PROFILE=/nix/var/nix/profiles/system
UNIT=nrs2-switch-to-configuration
STALL_AFTER=45 # seconds of activation before the watchdog first speaks
STALL_EVERY=30 # … and how often it repeats

mode='switch'
case "${1:-}" in
  --dry) mode='dry'; shift ;;
  --test) mode='test'; shift ;;
esac

step() { printf '%s>%s %s\n' "$BLUE" "$NC" "$*" >&2; }
warn() { printf '%swarning:%s %s\n' "$YELLOW" "$NC" "$*" >&2; }
fail() { printf '%serror:%s %s\n' "$RED" "$NC" "$*" >&2; }

# nix's --flake <path> does not follow a path that is itself a symlink, and
# ~/src/dotfiles is one on nebula.
flake="$(readlink -f "$HOME/src/dotfiles")"
os="$(uname -s)"
case "$os" in
  Linux)
    host="$(uname -n)"
    attr="nixosConfigurations.$host.config.system.build.toplevel"
    essentials=(bin/switch-to-configuration nixos-version init sw/bin)
    ;;
  Darwin)
    # What nh and darwin-rebuild use: the Bonjour name, not `uname -n`.
    host="$(scutil --get LocalHostName)"
    attr="darwinConfigurations.$host.config.system.build.toplevel"
    essentials=(activate sw/bin/darwin-rebuild)
    ;;
  *)
    fail "unsupported OS: $os"
    exit 1
    ;;
esac
# Resolved before sudo, whose secure path may not carry it.
nix_bin="$(command -v nix)"

# The out-link is the only GC root for the new closure until the profile is set.
tmp="$(mktemp -d -t nrs2.XXXXXX)"
watchdog=''
cleanup() {
  if [ -n "$watchdog" ]; then kill "$watchdog" 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT

timings=()
lap_start=$EPOCHREALTIME
lap() { # lap <label>: record the time since the previous lap
  local now=$EPOCHREALTIME
  timings+=("$(awk -v a="$lap_start" -v b="$now" -v l="$1" 'BEGIN { printf "%-10s %7.2fs", l, b - a }')")
  lap_start=$now
}

generation_of() { # generation_of <store path>: "gen N", or the bare name
  local link
  for link in "$SYSTEM_PROFILE"-*-link; do
    if [ "$(readlink -f "$link")" = "$1" ]; then
      link="${link##*/system-}"
      echo "gen ${link%-link}"
      return
    fi
  done
  echo "${1##*/}"
}

pam_glibc() { # pam_glibc <system>: the glibc that system's linux-pam links
  local pam
  pam="$(nix-store -qR "$1" | grep -m1 -- '-linux-pam-[0-9.]*$' || true)"
  if [ -n "$pam" ]; then
    nix-store -q --references "$pam" | grep -E -- '-glibc-[0-9.]+-[0-9]+$' || true
  fi
}

kernel_version() { # kernel_version <system>: its kernel's modules directory name
  local d
  for d in "$1"/kernel-modules/lib/modules/*; do
    echo "${d##*/}"
    return
  done
}

unpack_kernel() { # unpack_kernel <bzImage> <out>: decompress its payload (as extract-ikconfig does)
  local magic off
  for magic in '\x28\xb5\x2f\xfd:zstd' '\xfd\x37\x7a\x58\x5a\x00:xz' '\x1f\x8b\x08:gzip'; do
    off="$(LC_ALL=C grep -obUaP "${magic%%:*}" "$1" | head -1 | cut -d: -f1 || true)"
    if [ -n "$off" ]; then
      # Trailing data after the stream makes the decompressor exit non-zero.
      tail -c +"$((off + 1))" "$1" | "${magic##*:}" -dc >"$2" 2>/dev/null || true
      return
    fi
  done
}

toolchain_of() { # toolchain_of: the "(gcc …, GNU ld …)" part of a "Linux version" banner on stdin
  sed -E 's/^Linux version [^ ]+ \([^)]*\) \(//; s/\) #[0-9].*$//'
}

config_changes() { # config_changes <old .config> <new .config>: "NAME old → new" lines
  awk '
    /^CONFIG_/ { k = substr($0, 1, index($0, "=") - 1); v = substr($0, index($0, "=") + 1) }
    /^# CONFIG_.* is not set$/ { k = $2; v = "n" }
    !/^CONFIG_/ && !/^# CONFIG_.* is not set$/ { next }
    FNR == NR { old[k] = v; next }
    { new[k] = v }
    END {
      for (k in old) if (!(k in new)) print k, old[k], "→ (gone)"
      for (k in new) if (!(k in old)) print k, "(new) →", new[k]
        else if (old[k] != new[k]) print k, old[k], "→", new[k]
    }' "$1" "$2" | sort
}

module_packages() { # module_packages <system>: packages aggregated into its kernel-modules
  nix-store -q --references "$(readlink -f "$1/kernel-modules")" | sed -E 's#^/nix/store/[a-z0-9]{32}-##' | sort
}

kernel_report() { # what a reboot would change about the kernel, if anything
  local was now old_params new_params changes running_tc new_tc removed added
  local -a lines=()
  local same_kernel=1
  if [ "$(readlink -f /run/booted-system/kernel)" != "$(readlink -f /run/current-system/kernel)" ]; then same_kernel=0; fi
  old_params="$(cat /run/booted-system/kernel-params)" new_params="$(cat /run/current-system/kernel-params)"
  removed="$(comm -23 <(module_packages /run/booted-system) <(module_packages /run/current-system) | paste -sd' ')"
  added="$(comm -13 <(module_packages /run/booted-system) <(module_packages /run/current-system) | paste -sd' ')"
  if [ "$same_kernel" -eq 1 ] && [ "$old_params" = "$new_params" ] && [ -z "$removed$added" ]; then return; fi

  was="$(kernel_version /run/booted-system)" now="$(kernel_version /run/current-system)"
  if [ "$same_kernel" -eq 0 ]; then
    # The running kernel describes itself in /proc; the new one only inside its
    # compressed image, so unpack that for its banner and its embedded config.
    unpack_kernel "$(readlink -f /run/current-system/kernel)" "$tmp/vmlinux"
    running_tc="$(toolchain_of </proc/version)"
    new_tc="$(LC_ALL=C grep -aoE -m1 'Linux version [[:print:]]+' "$tmp/vmlinux" | head -1 | toolchain_of || true)"
    if [ "$was" != "$now" ]; then lines+=("kernel     $was → $now"); fi
    if [ -z "$new_tc" ]; then
      lines+=("toolchain  (could not read the new kernel image)")
    elif [ "$running_tc" != "$new_tc" ]; then
      lines+=("toolchain  $running_tc → $new_tc")
    fi
    if [ -r /proc/config.gz ] && LC_ALL=C grep -q IKCFG_ST "$tmp/vmlinux" 2>/dev/null; then
      local cfg_at
      cfg_at="$(LC_ALL=C grep -obUa IKCFG_ST "$tmp/vmlinux" | head -1 | cut -d: -f1 || true)"
      tail -c +"$((cfg_at + 9))" "$tmp/vmlinux" | gzip -dc >"$tmp/new.config" 2>/dev/null || true
      zcat /proc/config.gz >"$tmp/running.config"
      changes="$(config_changes "$tmp/running.config" "$tmp/new.config")"
      if [ -n "$changes" ]; then
        lines+=("config     $(wc -l <<<"$changes") option(s) changed:")
        while IFS= read -r c; do lines+=("             $c"); done < <(head -12 <<<"$changes")
        if [ "$(wc -l <<<"$changes")" -gt 12 ]; then lines+=("             …"); fi
      fi
    fi
    rm -f "$tmp/vmlinux" "$tmp/new.config" "$tmp/running.config"
    if [ "${#lines[@]}" -eq 0 ]; then
      lines+=("kernel     $now rebuilt; same version, toolchain and config (other build inputs changed)")
    fi
  fi
  if [ "$old_params" != "$new_params" ]; then lines+=("params     $old_params" "        →  $new_params"); fi
  if [ -n "$removed" ]; then lines+=("modules    − $removed"); fi
  if [ -n "$added" ]; then lines+=("modules    + $added"); fi

  warn "a reboot changes the kernel setup:"
  printf '  %s\n' "${lines[@]}" >&2
}

leftover_lists() { # NixOS only: switch-to-configuration's resume lists
  local f
  for f in /run/nixos/{start,restart,reload}-list "${XDG_RUNTIME_DIR:-/run/user/$UID}"/nixos/{start,restart,reload}-list; do
    if [ -s "$f" ]; then echo "$f"; fi
  done
}

report_linux() {
  local failed booted_glibc current_glibc
  local -a lists
  mapfile -t lists < <(leftover_lists)
  if [ "${#lists[@]}" -gt 0 ]; then
    warn "plan lists remain, so a switch did not finish; the next run replays them:"
    printf '  %s\n' "${lists[@]}" >&2
  fi
  failed="$(systemctl --failed --no-legend --plain --no-pager 2>/dev/null || true)"
  if [ -n "$failed" ]; then warn "failed system units:"; printf '%s\n' "$failed" >&2; fi
  failed="$(systemctl --user --failed --no-legend --plain --no-pager 2>/dev/null || true)"
  if [ -n "$failed" ]; then warn "failed user units:"; printf '%s\n' "$failed" >&2; fi
  kernel_report
  # Processes started at boot (ly, the lock screen) keep the boot-time glibc
  # while /etc/pam.d switches now; see docs/noctalia.md.
  booted_glibc="$(pam_glibc /run/booted-system)"
  current_glibc="$(pam_glibc /run/current-system)"
  if [ "$booted_glibc" != "$current_glibc" ]; then
    warn "PAM glibc changed since boot (${booted_glibc#*-glibc-} -> ${current_glibc#*-glibc-}): reboot before logging out"
  fi
}

report() {
  local current profile
  current="$(readlink -f /run/current-system)"
  profile="$(readlink -f "$SYSTEM_PROFILE")"

  printf '\n%s── state ──%s\n' "$BLUE" "$NC" >&2
  # nix-darwin keeps no /run/booted-system.
  if [ -e /run/booted-system ]; then
    printf '  booted        %s\n' "$(generation_of "$(readlink -f /run/booted-system)")" >&2
  fi
  printf '  running       %s\n  boot default  %s\n' "$(generation_of "$current")" "$(generation_of "$profile")" >&2
  if [ "$current" != "$profile" ]; then
    warn "the running system is not the boot default; a reboot would come back on $(generation_of "$profile")"
  fi
  if [ "$os" = Linux ]; then report_linux; fi

  if [ "${#timings[@]}" -gt 0 ]; then
    printf '%s── timings ──%s\n' "$BLUE" "$NC" >&2
    printf '  %s\n' "${timings[@]}" >&2
  fi
}

start_watchdog() {
  (
    waited=0
    while sleep 5; do
      waited=$((waited + 5))
      if [ "$waited" -ge "$STALL_AFTER" ] && [ $(((waited - STALL_AFTER) % STALL_EVERY)) -eq 0 ]; then
        printf '%snrs2:%s activation has run %ss; pending jobs:\n' "$YELLOW" "$NC" "$waited" >&2
        systemctl list-jobs --no-legend --no-pager >&2 || true
        systemctl --user list-jobs --no-legend --no-pager >&2 || true
      fi
    done
  ) &
  watchdog=$!
}

stop_watchdog() {
  if [ -n "$watchdog" ]; then
    kill "$watchdog" 2>/dev/null || true
    wait "$watchdog" 2>/dev/null || true
    watchdog=''
  fi
}

set_profile() {
  step "setting $SYSTEM_PROFILE"
  # -H: macOS sudo keeps the caller's $HOME, and nix then warns about it.
  sudo -H "$nix_bin" build --no-link --profile "$SYSTEM_PROFILE" "$out"
  lap profile
}

# ---- activation, NixOS ------------------------------------------------------
activate_nixos() {
  local rc interrupted systemd_run
  local -a env_args=()
  systemd_run="$(command -v systemd-run)"
  if systemctl is-active --quiet "$UNIT.service"; then
    fail "$UNIT.service from an earlier run is still active"
    printf '  follow: journalctl -fu %s\n  stop:   sudo systemctl stop %s\n' "$UNIT" "$UNIT" >&2
    exit 1
  fi
  if [ -n "${LOCALE_ARCHIVE:-}" ]; then env_args+=(-E "LOCALE_ARCHIVE=$LOCALE_ARCHIVE"); fi
  if [ -n "${NIXOS_NO_CHECK:-}" ]; then env_args+=(-E "NIXOS_NO_CHECK=$NIXOS_NO_CHECK"); fi

  step "activating: switch-to-configuration test, as $UNIT.service"
  # Ctrl-C ends only systemd-run (exit 130); the unit runs on to completion.
  interrupted=0
  trap 'interrupted=1' INT
  start_watchdog
  set +e
  sudo "$systemd_run" --collect --no-ask-password --quiet --service-type=exec \
    --unit="$UNIT" --wait --verbose --output=cat "${env_args[@]}" \
    "$out/bin/switch-to-configuration" test
  rc=$?
  set -e
  stop_watchdog
  trap - INT
  lap activate

  if [ "$interrupted" -eq 1 ] || [ "$rc" -eq 130 ]; then
    warn "detached; activation carries on as $UNIT.service under PID 1"
    printf '  follow: journalctl -fu %s\n  stop:   sudo systemctl stop %s\n' "$UNIT" "$UNIT" >&2
    printf '  then re-run nrs2 to set the profile and the boot entry\n' >&2
    report
    exit 130
  fi
  case "$rc" in
    0) ;;
    100)
      # The init interface changed: nothing was activated, and the new config
      # needs a reboot, so still make it the boot default (unless --test).
      warn "switch-to-configuration exited 100: incompatible init; the new config applies after a reboot"
      ;;
    4)
      fail "activation finished, but a unit failed (exit 4); the profile and boot entry stay on the old generation"
      report
      exit 4
      ;;
    *)
      fail "activation failed (exit $rc); the profile and boot entry stay on the old generation"
      report
      exit "$rc"
      ;;
  esac
  if [ "$mode" = test ]; then return; fi

  set_profile
  step "adding the configuration to the bootloader"
  sudo "$out/bin/switch-to-configuration" boot
  lap boot
}

# ---- activation, darwin -----------------------------------------------------
# Mirrors nh darwin switch: profile first, then the NEW generation's own
# darwin-rebuild (it sets HOME, PATH and NIX_REMOTE for root and handles any
# legacy activate-user). Activation is root-only in current nix-darwin.
activate_darwin() {
  local rc
  if [ "$mode" = test ]; then
    step "checking: darwin-rebuild check (system.checks, no activation)"
    set +e
    sudo -H "$out/sw/bin/darwin-rebuild" check --flake "$flake#$host"
    rc=$?
    set -e
    lap check
    if [ "$rc" -ne 0 ]; then fail "darwin-rebuild check failed (exit $rc)"; report; exit "$rc"; fi
    return
  fi

  set_profile
  step "activating: darwin-rebuild activate"
  set +e
  sudo -H "$out/sw/bin/darwin-rebuild" activate
  rc=$?
  set -e
  lap activate
  if [ "$rc" -ne 0 ]; then
    fail "activation failed (exit $rc); the profile already points at the new generation, so re-run nrs2 once fixed"
    report
    exit "$rc"
  fi
}

# ---- pre-flight -------------------------------------------------------------
if [ "$os" = Linux ] && [ "$mode" != dry ]; then
  mapfile -t lists < <(leftover_lists)
  if [ "${#lists[@]}" -gt 0 ]; then
    warn "a previous switch was interrupted; this run replays its plan:"
    for f in "${lists[@]}"; do printf '  %s: %s\n' "$f" "$(paste -sd' ' "$f")" >&2; done
  fi
fi

# ---- build, diff, validate (as you) ----------------------------------------
step "building $host from $flake"
nom build "$flake#$attr" --out-link "$tmp/result" "$@"
out="$(readlink -f "$tmp/result")"
lap build

step "changes: /run/current-system → ${out##*/}"
dix /run/current-system "$out" || warn "dix failed; continuing without a diff"
lap diff

for f in "${essentials[@]}"; do
  if [ ! -e "$out/$f" ]; then
    fail "$out lacks $f; refusing to activate it"
    exit 1
  fi
done

if [ "$mode" = dry ]; then
  report
  exit 0
fi

# ---- activate (root) ---------------------------------------------------------
step "authenticating for activation"
sudo -v
lap auth

if [ "$os" = Linux ]; then activate_nixos; else activate_darwin; fi

report
printf '%sdone%s\n' "$GREEN" "$NC" >&2
