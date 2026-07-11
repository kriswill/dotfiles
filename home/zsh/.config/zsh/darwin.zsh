# ~/.config/zsh/darwin.zsh — Darwin-specific setup, guarded so it stays a
# no-op on other hosts and OSes. Sourced by .zshrc (before the PATH export,
# since brew shellenv prepends its own paths).

## determinate-nixd's `completion zsh` takes ~300ms per shell to emit the same
## static script, so cache it and refresh only when the binary changes.
if command -v determinate-nixd > /dev/null; then
  _dnd_bin="$(command -v determinate-nixd)"
  _dnd_cache="$ZDOTDIR/.determinate-nixd-completion.zsh"
  if [[ ! -f $_dnd_cache || $_dnd_bin -nt $_dnd_cache ]]; then
    "$_dnd_bin" completion zsh > "$_dnd_cache"
  fi
  source "$_dnd_cache"
  unset _dnd_bin _dnd_cache
fi
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
