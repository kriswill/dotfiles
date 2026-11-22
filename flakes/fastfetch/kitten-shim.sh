# kitten — a shim that only fastfetch sees (./package.nix puts it first on
# fastfetch's PATH). fastfetch's `kitty-icat` logo runs
# `kitten icat …` with fixed arguments, and in a herdr-core terminal (hc, the
# Herdr app) those arguments draw nothing, for two reasons:
#
#   1. The pty reports no pixel size (TIOCGWINSZ ws_xpixel/ws_ypixel = 0,
#      herdrdev/herdr-app#81), and kitten refuses to draw without one, so
#      fastfetch falls back to the ASCII logo. The terminal does answer
#      `CSI 14 t`, so ask it and hand kitten the answer.
#   2. Left to detect, kitten may send the image as a temp file or shared
#      memory (it does inside `devenv shell`, whose own terminal layer says
#      yes to both). Herdr refuses file media (herdrdev/herdr-app#302), and its
#      viewer may be on another machine anyway, so the logo box stays blank.
#      Stream the bytes instead. That also skips kitten's detection queries,
#      whose replies Herdr sends late and twice (herdrdev/herdr-app#533): they
#      would land in the shell as typed text.
#
# Everything else passes through untouched: other kitten commands, and icat
# outside herdr-core, where ghostty and tmux already work. With no tty or no
# answer to the query, nothing is added either, and kitten decides as before.
# (A terminal no window is showing still answers, with a default 10x20 cell,
# so the logo is sent there too.) See README.md.

# The real kitten is the next one on PATH that isn't this file (-ef, so a
# link to the shim can't send it round in circles).
real=
IFS=: read -ra dirs <<<"$PATH"
for dir in "${dirs[@]}"; do
  [[ -n $dir && -x $dir/kitten && ! $dir/kitten -ef ${BASH_SOURCE[0]} ]] || continue
  real=$dir/kitten
  break
done
if [[ -z $real ]]; then
  echo "kitten: not found on PATH" >&2
  exit 127
fi

[[ ${1:-} == icat && -n ${HC_TERMINAL_ID:-} ]] || exec "$real" "$@"
shift

# Ask the terminal for its text area in pixels. The reply is
# `ESC [ 4 ; <height> ; <width> t`; herdr-core answers it itself, once.
# Prints kitten's `--use-window-size` value: cols,rows,width_px,height_px.
window_size() {
  local saved head height width rows cols
  exec 3<>/dev/tty || return 1
  saved=$(stty -g <&3) || return 1
  # No echo and no line buffering before the query goes out, so the reply
  # can't be echoed or held back until a newline. The 0.3 s wait for a
  # terminal that never answers has to be read's own -t: with -d, bash sets
  # the terminal to block for the read, which undoes a stty `min 0 time N`.
  trap 'stty "$saved" <&3' EXIT
  stty -icanon -echo <&3
  printf '\033[14t' >&3
  IFS=';' read -r -d t -t 0.3 -u 3 head height width || true
  stty "$saved" <&3
  trap - EXIT
  read -r rows cols < <(stty size <&3) || return 1
  exec 3>&-
  [[ $head == *'[4' && $height =~ ^[1-9][0-9]*$ && $width =~ ^[1-9][0-9]*$ ]] || return 1
  echo "$cols,$rows,$width,$height"
}

if size=$(window_size 2>/dev/null); then
  exec "$real" icat --transfer-mode=stream --use-window-size="$size" "$@"
fi
exec "$real" icat "$@"
