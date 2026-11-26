# herdr-askpass: sudo's password prompt as a dialog in the Herdr window you
# are looking at the hc terminal from, whichever machine runs sudo.
#
#   usage: herdr-askpass [prompt]   SUDO_ASKPASS, for agents in hc terminals
#
# sudo runs its askpass program for `sudo -A`, and on its own when it has no
# terminal to ask on while SUDO_ASKPASS and DISPLAY are both set. Homebrew
# adds -A to every sudo whenever SUDO_ASKPASS is set, so this is meant for an
# agent's environment only (Claude Code's settings.json `env`), not exported
# system-wide. Still, with a terminal to ask on it asks there, as sudo would.
#
# Without one (an agent's shell, such as Claude Code's Bash tool), in an hc
# terminal ($HC_TERMINAL_ID), it starts a short-lived terminal on this
# machine's core, labelled herdr-askpass=1 and herdr-askpass.for=<the asking
# terminal>, that runs the prompt (herdr-askpass --read). herdr-core shows
# every terminal to every Herdr window connected to this machine, and the
# herdr-askpass mod in each (home/herdr-app/.config/herdr-app/mods/
# herdr-askpass) opens that one as a dialog. What you type there reaches the
# prompt like any keystroke, with echo off for the whole prompt; the prompt
# writes it to a FIFO in a private (0700) directory that only this process
# reads, and this prints it for sudo. It is never in a label, an argument,
# the prompt's screen or a file. sudo's prompt text and command line reach
# the prompt as 0600 files in that directory, not as arguments, because
# herdr-core shows a terminal's argv to every connected window.
#
# The prompt answers with one line on the FIFO: P:<password>, or C when
# cancelled (Esc, ctrl-c, or the dialog's Cancel, which kills the prompt
# terminal). No answer within $HERDR_ASKPASS_TIMEOUT seconds (default 180), or
# the prompt gone without one: exit 1, so sudo has no password and fails. If
# this process dies without cleaning up (SIGKILL from a tool's timeout), the
# prompt notices within a second, removes the directory and ends, which
# closes the dialogs. Outside an hc terminal with no terminal to ask on, or
# with no hc on PATH, it exits 1 at once.
#
# Any process running as you can start a terminal with these labels, and so
# ask for your password the same way. The prompt shows sudo's command line
# (this process's parent), with control characters removed from it and from
# sudo's prompt, so neither can redraw what you see.

set -euo pipefail

BOLD=$'\e[1m'
DIM=$'\e[2m'
NC=$'\e[0m'

die() {
  echo "herdr-askpass: $*" >&2
  exit 1
}

# $1 without control characters, at most $2 characters. sudo's prompt comes
# from its caller (sudo -p): an escape sequence in it could clear or rewrite
# the command line shown above it.
clean() {
  local s=${1//[[:cntrl:]]/}
  printf '%s' "${s:0:$2}"
}

# ---- the prompt, in its own hc terminal ---------------------------------------
# usage: herdr-askpass --read <dir> <askpass pid> <deadline (epoch s)> <asker>
read_password() {
  dir=$1 askpass=$2 deadline=$3 asker=$4
  fifo=$dir/answer
  [[ -p $fifo ]] || die "$fifo is not a FIFO"

  # Echo off for the whole prompt, first: `read -s` turns it back on after
  # every key, so a key arriving between two reads would be echoed.
  saved_tty=$(stty -g 2>/dev/null || true)
  stty -echo 2>/dev/null || true
  trap '[[ -z $saved_tty ]] || stty "$saved_tty" 2>/dev/null || true' EXIT

  # Opened read-write now, while the FIFO surely exists: the answer never
  # blocks on a reader, and nothing looks the path up again later.
  exec 3<>"$fifo"
  local prompt command host
  prompt=$(<"$dir/prompt")
  command=$(<"$dir/command")

  answered=0
  answer() {
    if ((!answered)); then
      answered=1
      printf '%s\n' "$1" >&3
    fi
  }
  trap 'answer C; exit 130' INT HUP TERM

  # The askpass died without its cleanup (SIGKILL), or long past its deadline.
  orphaned() {
    ! kill -0 "$askpass" 2>/dev/null || ((EPOCHSECONDS >= deadline + 5))
  }

  host=$(uname -n)
  host=${host%%.*}
  printf '\n  %ssudo on %s%s%s\n' "$BOLD" "$host" "$NC" "${asker:+, asked by $asker}"
  if [[ -n $command ]]; then
    printf '\n  %s%s%s\n' "$DIM" "$command" "$NC"
  fi
  printf '\n  %sEnter sends it, Esc cancels%s\n\n  %s ' "$DIM" "$NC" "$prompt"

  # A key at a time, so Esc can cancel; nothing is echoed, as with sudo.
  local pw="" c rest st
  while :; do
    if IFS= read -rsn1 -t 1 c; then
      case $c in
        "") break ;; # Enter (or a paste's trailing newline)
        $'\e')
          # A lone Esc cancels; an arrow or function key's sequence is ignored.
          rest=""
          IFS= read -rsn8 -t 0.05 rest || true
          if [[ -z $rest ]]; then
            printf '\n'
            answer C
            exit 1
          fi
          ;;
        $'\x7f' | $'\b') pw=${pw%?} ;;
        $'\x15') pw="" ;; # ctrl-u
        *) pw+=$c ;;
      esac
    else
      st=$?
      if ((st <= 128)); then # end of input: the terminal went away
        answer C
        exit 1
      fi
      if orphaned; then
        answer C
        if ! kill -0 "$askpass" 2>/dev/null; then
          rm -rf "$dir"
        fi
        exit 1
      fi
    fi
  done
  printf '\n'
  answer "P:$pw"
}

if [[ ${1:-} == --read ]]; then
  shift
  (($# == 4)) || die "usage: herdr-askpass --read <dir> <askpass pid> <deadline> <asker>"
  read_password "$@"
  exit 0
fi

# ---- the askpass, under sudo -------------------------------------------------
prompt=$(clean "${1:-Password:}" 200)
timeout=${HERDR_ASKPASS_TIMEOUT:-180}
[[ $timeout =~ ^[0-9]+$ ]] || die "HERDR_ASKPASS_TIMEOUT is not a number of seconds: $timeout"
timeout=$((10#$timeout)) # 09 is nine seconds, not a bad octal number

# A terminal to ask on (sudo -A from a shell, Homebrew): ask there, as sudo
# would have.
if (: </dev/tty) 2>/dev/null; then
  pw=""
  printf '%s ' "$prompt" >/dev/tty
  if ! IFS= read -rs pw </dev/tty; then
    printf '\n' >/dev/tty
    exit 1
  fi
  printf '\n' >/dev/tty
  printf '%s\n' "$pw"
  exit 0
fi

[[ -n ${HC_TERMINAL_ID:-} ]] || die "no terminal to ask on, and not in an hc terminal, so there is no Herdr window to ask in"
command -v hc >/dev/null 2>&1 || die "no hc on PATH"

self=$0
[[ $self == /* ]] || self=$PWD/$self
asker=$(clean "$HC_TERMINAL_ID" 64)

dir=$(mktemp -d "${TMPDIR:-/tmp}/herdr-askpass.XXXXXX") # 0700
term=""
cleanup() {
  if [[ -n $term ]]; then
    hc kill "$term" >/dev/null 2>&1 || true
  fi
  rm -rf "$dir"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

mkfifo -m 600 "$dir/answer"
(
  umask 077
  printf '%s' "$prompt" >"$dir/prompt"
  clean "$(ps -o args= -p "$PPID" 2>/dev/null || true)" 400 >"$dir/command"
)
exec 3<>"$dir/answer"
deadline=$((EPOCHSECONDS + timeout))

term=$(hc run --bg --json --no-parent --no-notify --rm --cwd / \
  --label herdr-askpass=1 --label "herdr-askpass.for=$asker" \
  -- "$self" --read "$dir" "$$" "$deadline" "$asker" 3>&- |
  jq -r '.address // empty') || true
[[ -n $term ]] || die "couldn't start the prompt terminal"

line=""
while :; do
  if IFS= read -r -t 1 -u 3 line; then
    break
  fi
  line=""
  if ! hc get "$term" --json 2>/dev/null | jq -e '.state == "live"' >/dev/null 2>&1; then
    # It ended: take an answer written just before it did.
    IFS= read -r -t 0.2 -u 3 line || line=""
    break
  fi
  ((EPOCHSECONDS < deadline)) || die "no answer within ${timeout}s (is a Herdr window with the herdr-askpass mod showing this machine?)"
done

case $line in
  P:*) printf '%s\n' "${line#P:}" ;;
  C) die "cancelled" ;;
  *) die "the prompt ended without an answer" ;;
esac
