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
#           → system profile → switch-to-configuration boot (the last two
#           skipped when GRUB's menu already boots this build and lists no
#           collected generation; see bootloader_current)
#   darwin  build (nom) → diff (dix) → validate → system profile
#           → <new generation>/sw/bin/darwin-rebuild activate
# What changes, each a finding in docs/nrs-pipeline.html:
#   - activation output is streamed live, not captured (F1), and rendered:
#     the dotfiles restow's NDJSON events become a live spinner + progress
#     line and a one-line summary, and switch-to-configuration's plan lines
#     get glyphs and colours — both OSes;
#   - every exit ends with a state report and per-stage timings (F4, F12) —
#     both OSes; failed units, kernel and PAM glibc drift are NixOS-only;
#   - NixOS only: activation runs as a transient unit under PID 1
#     (systemd-run), so Ctrl-C or a lost terminal detaches instead of killing
#     it mid-plan (F3); a watchdog names pending jobs when it stalls (F2); an
#     interrupted earlier plan is announced before it replays (F5). launchd has
#     no systemd-run equivalent wired here, so on darwin Ctrl-C interrupts
#     activation exactly as it does under nh.
#
#   nrs2 [--dry | --test | --plan] [--boot] [nix build args…]
#   nrs2 --status
#     --dry     build, diff and validate only; no root (like nrb)
#     --test    NixOS: activate without touching the profile or GRUB (like nrt)
#               darwin: darwin-rebuild check — run system.checks, no activation
#     --plan    NixOS: build, then preview the switch and change nothing:
#               switch-to-configuration dry-activate for the system units
#               (root), plus its user pass run dry as you, which dry-activate
#               itself skips; units the switch would restart while they are
#               mid-run are flagged (P10). darwin has no dry-activate: as --dry
#     --status  no build, no root: is this machine consistent? Generations and
#               the rollback window, leftover plans, pending jobs, failed
#               units, kernel and PAM drift; exits 1 if anything needs
#               attention (P17)
#     --boot    NixOS switch: rewrite the boot menu even when it is current
#     The modes are mutually exclusive; --boot warns where it does nothing
#     (with any mode, and on darwin, which has no boot menu). --dry and --plan
#     compare the kernel and PAM against the new build, the others against
#     the running system.
set -euo pipefail

RED=$'\e[1;31m' GREEN=$'\e[1;32m' YELLOW=$'\e[1;33m' BLUE=$'\e[1;34m' NC=$'\e[0m'
MAGENTA=$'\e[1;35m' CYAN=$'\e[1;36m' BOLD=$'\e[1m' DIM=$'\e[2m'
LIVE=1 # redraw a progress line in place; needs a terminal
if [ ! -t 2 ]; then
  RED='' GREEN='' YELLOW='' BLUE='' NC='' MAGENTA='' CYAN='' BOLD='' DIM=''
  LIVE=0
fi

SYSTEM_PROFILE=/nix/var/nix/profiles/system
UNIT=nrs2-switch-to-configuration
STALL_AFTER=45 # seconds of activation before the watchdog first speaks
STALL_EVERY=30 # … and how often it repeats

GRUB_CFG=/boot/grub/grub.cfg # root-only on nebula (the ESP is mounted 0700)

issues=0 # warnings printed; --status turns a non-zero count into exit 1
step() { printf '%s>%s %s\n' "$BLUE" "$NC" "$*" >&2; }
warn() {
  issues=$((issues + 1))
  printf '%swarning:%s %s\n' "$YELLOW" "$NC" "$*" >&2
}
fail() { printf '%serror:%s %s\n' "$RED" "$NC" "$*" >&2; }

mode='switch'
force_boot=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry | --test | --plan | --status)
      # A dry run must never activate, so a second, different mode is an error
      # rather than last-one-wins.
      if [ "$mode" != switch ] && [ "$mode" != "${1#--}" ]; then
        fail "--$mode and $1 are mutually exclusive"
        exit 2
      fi
      mode="${1#--}"
      shift
      ;;
    --boot) force_boot=1; shift ;;
    *) break ;;
  esac
done
if [ "$mode" = status ] && [ $# -gt 0 ]; then
  fail "--status builds nothing, so it takes no build arguments: $*"
  exit 2
fi

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
if [ "$force_boot" -eq 1 ]; then
  if [ "$os" = Darwin ]; then
    warn "--boot does nothing on darwin (no boot menu); ignoring it"
  elif [ "$mode" != switch ]; then
    warn "--boot does nothing with --$mode (no boot entry is written); ignoring it"
  fi
fi
if [ "$os" = Darwin ] && [ "$mode" = plan ]; then
  warn "--plan: nix-darwin has no dry-activate, so this only builds and diffs (as --dry)"
  mode=dry
fi
# The system the kernel and PAM checks compare against /run/booted-system:
# the running one, or, for --dry and --plan, the new build (set once built),
# so a preview says what switching and then rebooting would change.
target=/run/current-system
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
  # Several generations can point at one build (a revert re-adds it), so
  # prefer the one the profile selects, then the newest. Compared as numbers:
  # glob order is lexicographic and goes wrong past 999 → 1000.
  local link n best=''
  if [ "$(readlink -f "$SYSTEM_PROFILE")" = "$1" ]; then
    link="$(readlink "$SYSTEM_PROFILE")"
    link="${link##*system-}"
    echo "gen ${link%-link}"
    return
  fi
  for link in "$SYSTEM_PROFILE"-*-link; do
    if [ "$(readlink -f "$link")" = "$1" ]; then
      n="${link##*/system-}"
      n="${n%-link}"
      if [ -z "$best" ] || [ "$n" -gt "$best" ]; then best=$n; fi
    fi
  done
  if [ -n "$best" ]; then echo "gen $best"; else echo "${1##*/}"; fi
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

kernel_report() { # what a reboot (into $target) would change about the kernel, if anything
  local was now old_params new_params changes running_tc new_tc removed added
  local -a lines=()
  local same_kernel=1
  if [ "$(readlink -f /run/booted-system/kernel)" != "$(readlink -f "$target/kernel")" ]; then same_kernel=0; fi
  old_params="$(cat /run/booted-system/kernel-params)" new_params="$(cat "$target/kernel-params")"
  removed="$(comm -23 <(module_packages /run/booted-system) <(module_packages "$target") | paste -sd' ')"
  added="$(comm -13 <(module_packages /run/booted-system) <(module_packages "$target") | paste -sd' ')"
  if [ "$same_kernel" -eq 1 ] && [ "$old_params" = "$new_params" ] && [ -z "$removed$added" ]; then return; fi

  was="$(kernel_version /run/booted-system)" now="$(kernel_version "$target")"
  if [ "$same_kernel" -eq 0 ]; then
    # The running kernel describes itself in /proc; the new one only inside its
    # compressed image, so unpack that for its banner and its embedded config.
    unpack_kernel "$(readlink -f "$target/kernel")" "$tmp/vmlinux"
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

  if [ "$target" = /run/current-system ]; then
    warn "a reboot changes the kernel setup:"
  else
    warn "after switching to this build, a reboot changes the kernel setup:"
  fi
  printf '  %s\n' "${lines[@]}" >&2
}

leftover_lists() { # NixOS only: switch-to-configuration's resume lists
  local f
  for f in /run/nixos/{start,restart,reload}-list "${XDG_RUNTIME_DIR:-/run/user/$UID}"/nixos/{start,restart,reload}-list; do
    if [ -s "$f" ]; then echo "$f"; fi
  done
}

report_linux() {
  local failed jobs booted_glibc target_glibc
  local -a lists
  if [ "$mode" = status ]; then
    if systemctl is-active --quiet "$UNIT.service"; then
      warn "an nrs2 activation is still running, detached, as $UNIT.service"
      printf '  follow: journalctl -fu %s\n' "$UNIT" >&2
    fi
    jobs="$(systemctl list-jobs --no-legend --no-pager 2>/dev/null || true)"
    if [ -n "$jobs" ]; then warn "pending system jobs:"; printf '%s\n' "$jobs" >&2; fi
    jobs="$(systemctl --user list-jobs --no-legend --no-pager 2>/dev/null || true)"
    if [ -n "$jobs" ]; then warn "pending user jobs:"; printf '%s\n' "$jobs" >&2; fi
  fi
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
  target_glibc="$(pam_glibc "$target")"
  if [ "$booted_glibc" != "$target_glibc" ]; then
    if [ "$target" = /run/current-system ]; then
      warn "PAM glibc changed since boot (${booted_glibc#*-glibc-} -> ${target_glibc#*-glibc-}): reboot before logging out"
    else
      warn "this build changes PAM's glibc since boot (${booted_glibc#*-glibc-} -> ${target_glibc#*-glibc-}): after switching, reboot before logging out"
    fi
  fi
}

generations() { # the system profile's generations: how many, and how far back a rollback reaches
  local link n min='' max='' count=0 ts age
  for link in "$SYSTEM_PROFILE"-*-link; do
    [ -L "$link" ] || continue
    n="${link##*/system-}"
    n="${n%-link}"
    count=$((count + 1))
    if [ -z "$min" ] || [ "$n" -lt "$min" ]; then min=$n; fi
    if [ -z "$max" ] || [ "$n" -gt "$max" ]; then max=$n; fi
  done
  if [ "$count" -eq 0 ]; then return; fi
  # A generation link is made when its generation is, and never touched again.
  ts="$(stat -c %Y "$SYSTEM_PROFILE-$min-link")"
  age=$((EPOCHSECONDS - ts))
  if [ "$age" -ge 86400 ]; then age="$((age / 86400))d"; else age="$((age / 3600))h"; fi
  if [ "$count" -eq 1 ]; then
    printf '  generations   1 (gen %s): nothing to roll back to\n' "$min" >&2
  else
    printf '  generations   %d (gen %s … gen %s); oldest from %s, %s ago\n' \
      "$count" "$min" "$max" "$(date -d "@$ts" +%F)" "$age" >&2
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
  if [ "$mode" = status ]; then generations; fi
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

# ---- activity rendering -----------------------------------------------------
# Activation output streams in line by line. The dotfiles restow
# (lib/stow-restow-script.nix) speaks NDJSON: its events drive a live
# spinner + progress line on a terminal and end in a one-line summary, with
# heals, conflicts and reloads listed under it. switch-to-configuration's own
# plan lines get a glyph and a colour; anything else passes through.
SPINNER=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
r_status='' # the live line currently drawn, if any
r_total=0 r_done=0 r_spin=0 r_pkg='' r_reason='' r_links=0
r_notes=()

draw_status() { # draw_status <text>: (re)draw the live line
  if [ "$LIVE" -eq 1 ]; then
    r_status="$1"
    printf '\r\e[K%s' "$1" >&2
  fi
}

clear_status() {
  if [ -n "$r_status" ]; then
    printf '\r\e[K' >&2
    r_status=''
  fi
}

emit() { # emit <line>: print a whole line above the live line
  local keep="$r_status"
  clear_status
  printf '%s\n' "$1" >&2
  if [ -n "$keep" ]; then draw_status "$keep"; fi
}

progress_bar() { # progress_bar <done> <total> <width>
  local fill i filled='' empty='' total=$2
  if [ "$total" -lt 1 ]; then total=1; fi
  fill=$(($1 * $3 / total))
  for ((i = 0; i < $3; i++)); do
    if [ "$i" -lt "$fill" ]; then filled+='█'; else empty+='░'; fi
  done
  printf '%s%s%s%s%s' "$GREEN" "$filled" "$DIM" "$empty" "$NC"
}

stow_status() {
  local frame="${SPINNER[r_spin % ${#SPINNER[@]}]}"
  r_spin=$((r_spin + 1))
  printf '  %s%s%s %sstow%s %s %s%d/%d%s %s%s%s' "$CYAN" "$frame" "$NC" "$BOLD" "$NC" \
    "$(progress_bar "$r_done" "$r_total" 20)" "$BOLD" "$r_done" "$r_total" "$NC" "$DIM" "$r_pkg" "$NC"
}

stow_event() { # stow_event <ndjson line>
  local ev pkg files ms reason link what packages skipped ok conflicts healed dir status msg m glyph summary
  IFS=$'\x1f' read -r ev pkg files ms reason link what packages skipped ok conflicts healed dir status < <(
    jq -r '[.stow, .pkg, .files, .ms, .reason, .link, .what, .packages, .skipped, .ok, .conflicts, .healed, .dir, .status]
      | map(if . == null then "" else tostring end) | join("\u001f")' <<<"$1" 2>/dev/null || true
  )
  case "$ev" in
    begin)
      r_total=$packages r_done=0 r_pkg='' r_links=0 r_notes=()
      draw_status "$(stow_status)"
      ;;
    skip) r_reason=$reason ;;
    heal)
      r_notes+=("    ${YELLOW}↺${NC} healed ${DIM}${link/#"$HOME"/\~}${NC}")
      draw_status "$(stow_status)"
      ;;
    ok | conflict)
      r_done=$((r_done + 1)) r_pkg=$pkg
      if [ "$ev" = ok ]; then r_links=$((r_links + ${files:-0})); fi
      msg="$(jq -r '.msg // ""' <<<"$1" 2>/dev/null || true)"
      if [ "$ev" = conflict ]; then
        r_notes+=("    ${RED}✗${NC} ${BOLD}${pkg}${NC} conflicted, skipped")
      elif [ -n "$msg" ]; then
        r_notes+=("    ${YELLOW}!${NC} ${BOLD}${pkg}${NC} stow said:")
      fi
      if [ -n "$msg" ]; then
        while IFS= read -r m; do r_notes+=("        ${DIM}${m}${NC}"); done < <(head -6 <<<"$msg")
      fi
      draw_status "$(stow_status)"
      ;;
    end)
      clear_status
      glyph="${GREEN}✔${NC}"
      if [ "$conflicts" -gt 0 ]; then glyph="${YELLOW}⚠${NC}"; fi
      summary="  $glyph ${BOLD}stow${NC}  ${BOLD}${ok}${NC} packages ${DIM}·${NC} ${BOLD}${r_links}${NC} links"
      if [ "$conflicts" -gt 0 ]; then summary+=" ${DIM}·${NC} ${RED}${conflicts} conflicted${NC}"; fi
      if [ "$healed" -gt 0 ]; then summary+=" ${DIM}·${NC} ${YELLOW}${healed} healed${NC}"; fi
      if [ "$skipped" -gt 0 ]; then summary+=" ${DIM}· ${skipped} skipped${r_reason:+ ($r_reason)}${NC}"; fi
      summary+=" ${DIM}· $((ms / 1000)).$(printf '%02d' $((ms % 1000 / 10)))s${NC}"
      emit "$summary"
      for m in "${r_notes[@]}"; do emit "$m"; done
      r_notes=()
      ;;
    reload) emit "  ${MAGENTA}↻${NC} reloaded ${BOLD}${what}${NC}" ;;
    absent) emit "  ${YELLOW}⚠${NC} stow: ${dir} not present, skipped" ;;
    failed)
      clear_status
      emit "  ${RED}✗${NC} ${BOLD}stow${NC} failed (exit ${status:-?}); dotfiles may be partly linked"
      ;;
    *) emit "  $1" ;; # not a stow event after all
  esac
}

plan_line() { # plan_line <line>: style one line of activation output
  local l="$1" who='' rest
  case "$l" in
    'Starting [systemd-run] '* | 'Started [systemd-run] '*) return ;; # our step header covers it
    *'the following user units: '*) who=" ${DIM}(user)${NC}" ;;
  esac
  rest="${l#*: }"
  case "$l" in
    # dry-activate (--plan): the same plan, in the conditional
    'would NOT '*'the following '*) emit "  ${DIM}· would not restart${NC}${who} ${DIM}${rest}${NC}" ;;
    'would stop the following '*) emit "  ${RED}■${NC} would stop${who}    ${rest}" ;;
    'would reload the following '*) emit "  ${BLUE}⟳${NC} would reload${who}  ${rest}" ;;
    'would restart the following '*) emit "  ${YELLOW}↻${NC} would restart${who} ${rest}" ;;
    'would start the following '*) emit "  ${GREEN}▶${NC} would start${who}   ${rest}" ;;
    'would restart systemd') emit "  ${YELLOW}↻${NC} would restart systemd" ;;
    # sops-install-secrets' secret changes (no prefix of their own) and errors
    # (prefixed with its full store path); its key imports go to sops_import.
    'adding secret'* | 'adding template'* | 'would add secret'* | 'would add template'*)
      emit "  ${SOPS} ${GREEN}+${NC} ${l}" ;;
    'modifying secret'* | 'modifying template'* | 'would modify secret'* | 'would modify template'*)
      emit "  ${SOPS} ${YELLOW}~${NC} ${l}" ;;
    'removing secret'* | 'removing template'* | 'would remove secret'* | 'would remove template'*)
      emit "  ${SOPS} ${RED}−${NC} ${l}" ;;
    *'sops-install-secrets: '* | 'Cannot read ssh key '* | 'Cannot convert ssh key '* | 'Cannot write secring'* | 'Cannot write pubring'* | 'Cannot write key to age file'*)
      emit "  ${SOPS} ${RED}${l#*sops-install-secrets: }${NC}" ;;
    'NOT restarting'*'the following '*) emit "  ${DIM}· not restarting${NC}${who} ${DIM}${rest}${NC}" ;;
    'stopping'*'the following '*) emit "  ${RED}■${NC} stopping${who}   ${rest}" ;;
    'reloading'*'the following '*) emit "  ${BLUE}⟳${NC} reloading${who}  ${rest}" ;;
    'restarting'*'the following '*) emit "  ${YELLOW}↻${NC} restarting${who} ${rest}" ;;
    'starting'*'the following '*) emit "  ${GREEN}▶${NC} starting${who}   ${rest}" ;;
    'the following new units were started: '*) emit "  ${GREEN}+${NC} new units  ${rest}" ;;
    *[Ee]rror* | *[Ff]ailed*) emit "  ${RED}${l}${NC}" ;;
    *[Ww]arning* | *WARN*) emit "  ${YELLOW}${l}${NC}" ;;
    *... | 'Checking '* | 'Not checking '* | 'restarting '* | 'reloading '*) emit "  ${DIM}● ${l%...}${NC}" ;;
    *) emit "  $l" ;;
  esac
}

# sops-install-secrets runs twice per activation (setupSecretsForUsers before
# /etc, setupSecrets after; dry-activate too), and every run announces each
# key it imports: "sops-install-secrets: Imported /etc/ssh/ssh_host_rsa_key as
# GPG key with fingerprint <40 hex>", then the same for age. A run of those
# lines collapses into one, "⚿ sops  keys  rsa → GPG 646fb041…c17120 · …", and
# a key already shown in this activation is not shown again, so the second run
# prints nothing unless its keys differ. Secret changes and errors still print
# (plan_line).
SOPS="${MAGENTA}⚿${NC} ${BOLD}sops${NC} "
declare -A r_sops_seen=()
r_sops_new=()

sops_import() { # sops_import <"…: Imported <path> as <kind> key with fingerprint <fp>" line>
  local rest path kind fp name
  rest="${1#*: Imported }"
  path="${rest%% as *}"
  kind="${rest#* as }"
  kind="${kind%% key with fingerprint *}"
  fp="${rest##* fingerprint }"
  if [ -n "${r_sops_seen["$path $kind $fp"]:-}" ]; then return; fi
  r_sops_seen["$path $kind $fp"]=1
  name="${path##*/}"
  case "$name" in ssh_host_*_key) name="${name#ssh_host_}" name="${name%_key}" ;; esac
  if [ "${#fp}" -gt 16 ]; then fp="${fp:0:8}…${fp: -6}"; fi
  r_sops_new+=("${name} ${DIM}→${NC} ${kind} ${CYAN}${fp}${NC}")
}

sops_flush() { # print the imports collected since the last non-import line
  local k line=''
  if [ "${#r_sops_new[@]}" -eq 0 ]; then return; fi
  for k in "${r_sops_new[@]}"; do line+="${line:+ ${DIM}·${NC} }$k"; done
  emit "  ${SOPS} ${DIM}keys${NC}  $line"
  r_sops_new=()
}

# Homebrew bundle (nix-darwin's activation) prints one "Using <dep>" line per
# Brewfile entry. Those collapse into the live line and a one-line summary;
# anything else brew says (installs, upgrades, errors) still prints in full.
r_brew=0 r_brew_using=0

brew_status() { # brew_status <dependency>
  local frame="${SPINNER[r_spin % ${#SPINNER[@]}]}"
  r_spin=$((r_spin + 1))
  printf '  %s%s%s %sbrew%s %s%d%s checked %s%s%s' "$CYAN" "$frame" "$NC" "$BOLD" "$NC" \
    "$BOLD" "$r_brew_using" "$NC" "$DIM" "$1" "$NC"
}

brew_done() { # brew_done [<"`brew bundle` complete!" line>]
  local n summary
  clear_status
  r_brew=0
  n="${1#*complete! }"
  n="${n%% *}"
  if [[ "$n" =~ ^[0-9]+$ ]]; then
    summary="  ${GREEN}✔${NC} ${BOLD}brew${NC}  ${BOLD}${n}${NC} Brewfile dependencies ${DIM}· ${r_brew_using} already installed${NC}"
    if [ "$n" -gt "$r_brew_using" ]; then
      summary+=" ${DIM}·${NC} ${GREEN}$((n - r_brew_using)) installed or upgraded${NC}"
    fi
  else
    summary="  ${YELLOW}⚠${NC} ${BOLD}brew${NC}  bundle ended without its completion line ${DIM}(${r_brew_using} checked)${NC}"
  fi
  emit "$summary"
}

render_activity() { # render_activity: style the activation stream on stdin, to stderr
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *'sops-install-secrets: Imported '*' key with fingerprint '*)
        sops_import "$line"
        continue
        ;;
      *) sops_flush ;;
    esac
    if [ "$r_brew" -eq 1 ]; then
      case "$line" in
        'Using '*)
          r_brew_using=$((r_brew_using + 1))
          draw_status "$(brew_status "${line#Using }")"
          continue
          ;;
        *'brew bundle'*'complete!'*)
          brew_done "$line"
          continue
          ;;
        *...) brew_done '' ;; # the next activation step began without it
      esac
    fi
    case "$line" in
      'Homebrew bundle...')
        r_brew=1 r_brew_using=0
        draw_status "$(brew_status '')"
        ;;
      '{"stow":'*) stow_event "$line" ;;
      *) plan_line "$line" ;;
    esac
  done
  sops_flush
  if [ "$r_brew" -eq 1 ]; then brew_done ''; fi
  clear_status
}

# True when the profile + boot steps have nothing to do, judged from GRUB's
# own menu rather than any record of nrs2's: the boot default already IS this
# build, GRUB's default entry boots it, and every generation the menu lists
# still exists. The last check catches any GC since the menu was written
# (nightly timer, manual nix-collect-garbage, nh clean), whose dead entries
# drop into emergency mode when picked (2026-06-16); the first two catch a run
# cut off between profile and bootloader, and a menu someone else rewrote.
# install-grub writes each entry with init=<system>/init and the default
# "NixOS" entry first. grub.cfg is root-only, so it is read with the sudo
# credentials activation already obtained. Anything unexpected (no file, no
# entries, a changed format) answers "not current": the safe direction is to
# rewrite. Setting the profile to the same path adds no generation either way.
bootloader_current() {
  local cfg entry
  local -a inits
  [ "$(readlink -f "$SYSTEM_PROFILE")" = "$out" ] || return 1
  cfg="$(sudo cat "$GRUB_CFG" 2>/dev/null)" || return 1
  mapfile -t inits < <(grep -o 'init=/nix/store/[^ ]*/init' <<<"$cfg" | sed 's/^init=//' || true)
  [ "${#inits[@]}" -gt 0 ] || return 1
  [ "${inits[0]}" = "$out/init" ] || return 1
  for entry in "${inits[@]}"; do
    [ -e "$entry" ] || return 1
  done
}

set_profile() {
  step "setting $SYSTEM_PROFILE"
  # -H: macOS sudo keeps the caller's $HOME, and nix then warns about it.
  sudo -H "$nix_bin" build --no-link --profile "$SYSTEM_PROFILE" "$out"
  lap profile
}

# ---- activation, NixOS ------------------------------------------------------
refuse_if_detached() { # an earlier run's activation still holds switch-to-configuration's lock
  if systemctl is-active --quiet "$UNIT.service"; then
    fail "$UNIT.service from an earlier run is still active"
    printf '  follow: journalctl -fu %s\n  stop:   sudo systemctl stop %s\n' "$UNIT" "$UNIT" >&2
    exit 1
  fi
}

activate_nixos() {
  local rc interrupted systemd_run
  local -a env_args=()
  systemd_run="$(command -v systemd-run)"
  refuse_if_detached
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
    "$out/bin/switch-to-configuration" test 2>&1 | render_activity
  rc=${PIPESTATUS[0]}
  set -e
  stop_watchdog
  trap - INT
  lap activate

  if [ "$interrupted" -eq 1 ] || [ "$rc" -eq 130 ]; then
    if [ "$LIVE" -eq 1 ]; then printf '\r\e[K' >&2; fi # the renderer died mid-line
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
  if [ "$force_boot" -eq 0 ] && bootloader_current; then
    step "boot menu is current ($(generation_of "$out") is the default, no collected generations listed); bootloader untouched (--boot rewrites it)"
    return
  fi

  set_profile
  step "adding the configuration to the bootloader"
  # The pre-switch checks already ran in the `test` step above, against this
  # same generation; for `boot` they would only print "Not checking switch
  # inhibitors (action = boot)".
  set +e
  sudo env NIXOS_NO_CHECK=1 "$out/bin/switch-to-configuration" boot 2>&1 | render_activity
  rc=${PIPESTATUS[0]}
  set -e
  lap boot
  if [ "$rc" -ne 0 ]; then
    fail "bootloader update failed (exit $rc); the profile is set, the boot menu may still default to the old generation"
    report
    exit "$rc"
  fi
}

# ---- plan, NixOS (--plan) ----------------------------------------------------
# dry-activate prints the system plan and runs the dry-activate snippets, but
# it exits before switch-to-configuration-ng's per-user pass (do_user_switch),
# so on its own it never shows a user unit, the kind that hung nrs on
# 2026-10-24. nrs2 runs that pass itself, dry, the way stc-ng spawns it: its
# own binary, a cleared environment, NIXOS_ACTION=dry-activate. With that
# action the pass only reads unit files and the user manager's state, and
# record_unit writes no lists. It is stc-ng's internal interface, not a public
# one: if it moves, the preview says so and carries on without it.
plan_user_units() {
  local stc rc
  stc="$(readlink -f "$out/bin/.switch-to-configuration-wrapped" 2>/dev/null || true)"
  if [ ! -x "$stc" ]; then
    warn "no user-unit preview: $out has no bin/.switch-to-configuration-wrapped (stc-ng's layout changed?)"
    return
  fi
  set +e
  env -i XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}" \
    __NIXOS_SWITCH_TO_CONFIGURATION_PARENT_EXE="$stc" NIXOS_ACTION=dry-activate \
    TOPLEVEL="$out" OLD_TOPLEVEL="$(readlink -f /run/current-system)" \
    "$stc" 2>&1 | tee "$tmp/plan.user" | render_activity
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -ne 0 ]; then
    warn "the user-unit preview failed (exit $rc); stc-ng's internal user-pass interface may have changed"
  elif [ ! -s "$tmp/plan.user" ]; then
    emit "  ${DIM}· no user unit would change${NC}"
  fi
}

plan_hazards() { # units the plan restarts or starts that are mid-run right now
  local scope line u state
  local -a units hazards=()
  for scope in system user; do
    [ -f "$tmp/plan.$scope" ] || continue
    while IFS= read -r line; do
      # Stop-only units are left out: a stop job on a running oneshot
      # signals it and completes. A changed unit that is stopped is also
      # started again, so it is caught by its start line.
      case "$line" in
        'would restart the following '* | 'would start the following '*) ;;
        *) continue ;;
      esac
      IFS=', ' read -ra units <<<"${line#*: }"
      for u in "${units[@]}"; do
        if [ "$scope" = user ]; then
          state="$(systemctl --user show -P ActiveState -- "$u" 2>/dev/null || true)"
        else
          state="$(systemctl show -P ActiveState -- "$u" 2>/dev/null || true)"
        fi
        if [ "$state" = activating ] && [[ " ${hazards[*]} " != *" $u ($scope) "* ]]; then
          hazards+=("$u ($scope)")
        fi
      done
    done <"$tmp/plan.$scope"
  done
  if [ "${#hazards[@]}" -gt 0 ]; then
    # A start job for a oneshot completes only when the run exits, and the
    # switch blocks on those jobs, the user ones before it restarts the system
    # services it stopped (docs/nrs-pipeline.html, F2).
    warn "the switch would restart units that are mid-run (activating) now, and wait for each new run to finish:"
    printf '  %s\n' "${hazards[@]}" >&2
    printf '  let them finish (or stop them) before switching\n' >&2
  fi
}

plan_nixos() {
  local rc
  refuse_if_detached
  step "plan: switch-to-configuration dry-activate (system units; nothing changes)"
  set +e
  sudo "$out/bin/switch-to-configuration" dry-activate 2>&1 | tee "$tmp/plan.system" | render_activity
  rc=${PIPESTATUS[0]}
  set -e
  lap plan
  if [ "$rc" -ne 0 ]; then
    fail "dry-activate failed (exit $rc)"
    report
    exit "$rc"
  fi
  step "plan: user units for $(id -un) (stc-ng's user pass, dry; dry-activate skips it)"
  plan_user_units
  lap plan-user
  plan_hazards
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
    sudo -H "$out/sw/bin/darwin-rebuild" check --flake "$flake#$host" 2>&1 | render_activity
    rc=${PIPESTATUS[0]}
    set -e
    lap check
    if [ "$rc" -ne 0 ]; then fail "darwin-rebuild check failed (exit $rc)"; report; exit "$rc"; fi
    return
  fi

  set_profile
  step "activating: darwin-rebuild activate"
  set +e
  sudo -H "$out/sw/bin/darwin-rebuild" activate 2>&1 | render_activity
  rc=${PIPESTATUS[0]}
  set -e
  lap activate
  if [ "$rc" -ne 0 ]; then
    fail "activation failed (exit $rc); the profile already points at the new generation, so re-run nrs2 once fixed"
    report
    exit "$rc"
  fi
}

# ---- status (--status): nothing built, nothing changed, no root -------------
if [ "$mode" = status ]; then
  issues=0 # count only what the report finds
  report
  if [ "$issues" -eq 0 ]; then
    printf '%s✔ consistent:%s the running system is the boot default; nothing failed, pending or left over\n' "$GREEN" "$NC" >&2
    exit 0
  fi
  printf '%s⚠ %d thing(s) above need attention%s\n' "$YELLOW" "$issues" "$NC" >&2
  exit 1
fi

# ---- pre-flight -------------------------------------------------------------
if [ "$os" = Linux ] && [ "$mode" != dry ]; then
  mapfile -t lists < <(leftover_lists)
  if [ "${#lists[@]}" -gt 0 ]; then
    if [ "$mode" = plan ]; then
      warn "a previous switch was interrupted; the next switch replays its plan, which the preview includes:"
    else
      warn "a previous switch was interrupted; this run replays its plan:"
    fi
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
  target=$out
  report
  exit 0
fi

if [ "$mode" = plan ]; then
  step "authenticating for the plan (dry-activate needs root; it changes nothing)"
  sudo -v
  lap auth
  plan_nixos
  target=$out
  report
  printf '%splan only: nothing was changed; nrs2 applies it%s\n' "$GREEN" "$NC" >&2
  exit 0
fi

# ---- activate (root) ---------------------------------------------------------
step "authenticating for activation"
sudo -v
lap auth

if [ "$os" = Linux ]; then activate_nixos; else activate_darwin; fi

report
printf '%sdone%s\n' "$GREEN" "$NC" >&2
