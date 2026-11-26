# herdr-askpass: sudo's password prompt as a dialog in the Herdr window you
# are looking at the hc terminal from, whichever machine runs sudo.
#
#   usage: herdr-askpass [prompt]   SUDO_ASKPASS, for agents in hc terminals
#
# sudo runs its askpass program for `sudo -A`, and on its own when it has no
# terminal to ask on (an agent's shell, such as Claude Code's Bash tool) while
# SUDO_ASKPASS and DISPLAY are both set. In an hc terminal ($HC_TERMINAL_ID),
# this starts a short-lived terminal on this machine's core, labelled
# herdr-askpass=1 and herdr-askpass.for=<the asking terminal>, that runs the
# prompt (herdr-askpass --read). herdr-core shows every terminal to every
# Herdr window connected to this machine, and the herdr-askpass mod in each
# (home/herdr-app/.config/herdr-app/mods/herdr-askpass) opens that one as a
# dialog. What you type there reaches the prompt like any keystroke; the
# prompt writes it to a FIFO in a private directory that only this process
# reads, and this prints it for sudo. It is never in a label, an argument, the
# prompt's screen or a file.
#
# The prompt answers with one line on the FIFO: P:<password>, or C when
# cancelled (Esc, ctrl-c, or the dialog's Cancel, which kills the prompt
# terminal). No answer within $HERDR_ASKPASS_TIMEOUT seconds (default 180), or
# the prompt gone without one: exit 1, so sudo has no password and fails.
# Outside an hc terminal, or with no hc on PATH, it exits 1 at once.
#
# Any process running as you can start a terminal with these labels, and so
# ask for your password the same way. The prompt shows sudo's command line
# (this process's parent), so you can see what you are authorising.

die() {
  echo "herdr-askpass: $*" >&2
  exit 1
}

# ---- the prompt, in its own hc terminal ---------------------------------------
read_password() {
  local fifo=$1 prompt=$2 asker=$3 command=$4
  [[ -p $fifo ]] || die "$fifo is not a FIFO"
  # Opened read-write now, while the FIFO surely exists: the answer never
  # blocks on a reader, and nothing looks the path up again later.
  exec 3<>"$fifo"

  answered=0
  answer() {
    if ((!answered)); then
      answered=1
      printf '%s\n' "$1" >&3
    fi
  }
  trap 'answer C; exit 130' INT HUP TERM

  local host bold=$'\e[1m' dim=$'\e[2m' reset=$'\e[0m'
  host=$(uname -n)
  host=${host%%.*}
  printf '\n  %ssudo on %s%s%s\n' "$bold" "$host" "$reset" "${asker:+, asked by $asker}"
  if [[ -n $command ]]; then
    printf '\n  %s%s%s\n' "$dim" "$command" "$reset"
  fi
  printf '\n  %sEnter sends it, Esc cancels%s\n\n  %s ' "$dim" "$reset" "$prompt"

  # A key at a time, so Esc can cancel; nothing is echoed, as with sudo.
  local pw="" c rest
  while :; do
    if ! IFS= read -rsn1 c; then
      answer C
      exit 1
    fi
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
  done
  printf '\n'
  answer "P:$pw"
}

if [[ ${1:-} == --read ]]; then
  shift
  (($# == 4)) || die "usage: herdr-askpass --read <fifo> <prompt> <asker> <command>"
  read_password "$@"
  exit 0
fi

# ---- the askpass, under sudo -------------------------------------------------
prompt=${1:-Password:}
timeout=${HERDR_ASKPASS_TIMEOUT:-180}
[[ $timeout =~ ^[0-9]+$ ]] || die "HERDR_ASKPASS_TIMEOUT is not a number of seconds: $timeout"
[[ -n ${HC_TERMINAL_ID:-} ]] || die "not in an hc terminal, so there is no Herdr window to ask in"
command -v hc >/dev/null 2>&1 || die "no hc on PATH"

self=$0
[[ $self == /* ]] || self=$PWD/$self
command=$(ps -o args= -p "$PPID" 2>/dev/null || true)
command=${command:0:400}

dir=$(mktemp -d "${TMPDIR:-/tmp}/herdr-askpass.XXXXXX") # 0700
fifo=$dir/answer
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

mkfifo -m 600 "$fifo"
exec 3<>"$fifo"

term=$(hc run --bg --json --no-parent --no-notify --rm --cwd / \
  --label herdr-askpass=1 --label "herdr-askpass.for=$HC_TERMINAL_ID" \
  -- "$self" --read "$fifo" "$prompt" "$HC_TERMINAL_ID" "$command" 3>&- |
  jq -r '.address // empty') || true
[[ -n $term ]] || die "couldn't start the prompt terminal"

line=""
deadline=$((SECONDS + timeout))
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
  ((SECONDS < deadline)) || die "no answer within ${timeout}s (is a Herdr window with the herdr-askpass mod showing this machine?)"
done

case $line in
  P:*) printf '%s\n' "${line#P:}" ;;
  C) die "cancelled" ;;
  *) die "the prompt ended without an answer" ;;
esac
