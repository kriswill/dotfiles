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
## `brew shellenv` takes ~30ms per shell to emit the same static exports, so
## cache it and refresh only when the brew binary changes (same pattern as
## determinate-nixd's completion script above).
if [ -x /opt/homebrew/bin/brew ]; then
  _brew_bin=/opt/homebrew/bin/brew
  _brew_cache="$ZDOTDIR/.brew-shellenv.zsh"
  if [[ ! -f $_brew_cache || $_brew_bin -nt $_brew_cache ]]; then
    "$_brew_bin" shellenv > "$_brew_cache"
  fi
  source "$_brew_cache"
  unset _brew_bin _brew_cache
fi
