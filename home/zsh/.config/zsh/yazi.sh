# ~/.config/zsh/yazi.sh — `y` wraps yazi so quitting (q) cd's the shell into
# yazi's last directory; quit with Q to skip the cd. Quitting from search
# results yields a virtual `search://<keyword>//<dir>` URL instead of a path —
# recover the real dir, and never cd to anything that isn't one.
#
# Pure POSIX sh (no local/[[ ]]/read -d) so any POSIX shell (oksh, yash, ...)
# can source this same file. It must run in the current shell (it cd's), so
# variables are prefix-scoped and unset on the way out. Sourced by .zshrc.

y() {
  y_tmp=$(mktemp "${TMPDIR:-/tmp}/yazi-cwd.XXXXXX") || return 1
  yazi "$@" --cwd-file="$y_tmp"
  IFS= read -r y_cwd < "$y_tmp" || :
  rm -f -- "$y_tmp"
  case $y_cwd in
    search://*) y_cwd="/${y_cwd#search://*//}" ;;
  esac
  if [ -n "$y_cwd" ] && [ "$y_cwd" != "$PWD" ] && [ -d "$y_cwd" ]; then
    cd -- "$y_cwd"
  fi
  unset y_tmp y_cwd
}
